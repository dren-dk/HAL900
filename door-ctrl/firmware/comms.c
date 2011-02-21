#include <stdio.h>
#include <avr/io.h>
#include <util/delay.h>
#include <avr/eeprom.h> 

#include "ip_arp_udp_tcp.h"
#include "enc28j60.h"
#include "net.h"
#include "aes256.h"
#include "crc32.h"

#include "defines.h"
#include "telegram.h"
#include "comms.h"

#define BUFFER_SIZE 550

const uint8_t MYMAC[6] = ETHERNET_MAC;
const uint8_t MYIP[4]  = ETHERNET_IP;

const unsigned char AES_KEY[32] = {NODE_AES_KEY};


void initComms() {
  enc28j60Init(MYMAC);
  //enc28j60clkout(2); // change clkout from 6.25MHz to 12.5MHz
  _delay_loop_1(0); // 60us

  // 0x476 is PHLCON LEDA=links status, LEDB=receive/transmit
  enc28j60PhyWrite(PHLCON,0x476);
  init_ip_arp_udp_tcp(MYMAC, MYIP, 0);
}


/**********************************************************************************************/
unsigned int logSeq=0;
void broadcastLog(struct LogTelegram *lt) {
  lt->type = 'L';
  lt->seq = logSeq++;

  lt->crc32 = crc32((unsigned char*)lt, 12);

  fprintf(stdout, "Log, seq:%d, crc: %lu, type:%c\n", lt->seq, lt->crc32, lt->logType);
  aes256_context ctx;
  aes256_init(&ctx, AES_KEY);
  aes256_encrypt_ecb(&ctx, (unsigned char *)lt);
  unsigned char transmitBuffer[UDP_DATA_P+32];
  spam_udp(transmitBuffer, (char *)lt, 16, UDP_PORT, 4747);
}

void logPowerUp() {
  struct LogTelegram lt;
  lt.logType = 'P';

  broadcastLog(&lt);
}

void logDeny() {
  struct LogTelegram lt;
  lt.logType = 'D';

  broadcastLog(&lt);
}

void logLocked() {
  struct LogTelegram lt;
  lt.logType = 'L';

  broadcastLog(&lt);
}

void logUnlock(unsigned long hash) {
  struct LogTelegram lt;
  lt.logType = 'U';
  lt.item.hash = hash;

  broadcastLog(&lt);
}

void logExit() {
  struct LogTelegram lt;
  lt.logType = 'E';

  broadcastLog(&lt);
}

void logKey(unsigned char key) {
  struct LogTelegram lt;
  lt.logType = 'K';
  lt.item.key = key;

  broadcastLog(&lt);
}

void logRfid(unsigned long rfid) {
  struct LogTelegram lt;
  lt.logType = 'R';
  lt.item.rfid = rfid;

  broadcastLog(&lt);
}

void logSensors(unsigned char sensors) {
  struct LogTelegram lt;
  lt.logType = 'S';
  lt.item.sensors = sensors;

  broadcastLog(&lt);
}


/**********************************************************************************************/

void sendAnswerTelegram(unsigned char *request, char *telegram) { // Stomps on telegram and request!

  // Affix crc in the right place.
  *((unsigned long *)(telegram+12)) = crc32((unsigned char*)telegram, 12);
  //fprintf(stdout, "Sending reply UDP package, crc is: %lu\n", *((unsigned long *)(telegram+12)));
  aes256_context ctx;
  aes256_init(&ctx, AES_KEY);
  aes256_encrypt_ecb(&ctx, (unsigned char *)telegram);

  //unsigned char transmitBuffer[UDP_DATA_P+32];
  //  send_udp(transmitBuffer, telegram, 16, UDP_PORT, dip, dport);
  make_udp_reply_from_request(request, telegram, 16, UDP_PORT);
}

void handlePing(unsigned char *request, struct PingPongTelegram *ping) {
  //  fprintf(stdout, "Got ping package, replying with pong\n");

  struct PingPongTelegram pong;

  pong.type = 'P';
  pong.seq = ping->seq;
  for (int i=0;i<9;i++) {
    pong.payload[i] = ping->payload[i] ^ ((i & 1) ? 0xaa : 0xbb);
  }

  sendAnswerTelegram(request, (char *)&pong);
}

void handleGetState(unsigned char *request) {

  struct StateTelegram reply;
  reply.type = 'G';
  reply.seq = eeprom_read_word((uint16_t *)EEPROM_SEQ);
  reply.version = 0;
  reply.sensorState = 0; // TODO: Figure out what to hook up where.

  sendAnswerTelegram(request, (char *)&reply);
}

void handleAddKey(unsigned char *request, struct AddDeleteKeyTelegram *payload) {

  struct AddDeleteKeyAnswerTelegram reply;
  reply.type='A';
  reply.seq=payload->seq;
  reply.result = 0;

  unsigned int currentSeq = eeprom_read_word((uint16_t *)EEPROM_SEQ);
  if (currentSeq != 0xffff && currentSeq > payload->seq) {
    reply.result = 2; // NACK
    //fprintf(stdout, "Ignoring write of key, because sequence number %u < %u\n", payload->seq, currentSeq);
  } else {

    // Find the first free slot in EEPROM
    int free = 0;
    while (free < 250) {
      unsigned long v = eeprom_read_dword((uint32_t *)(EEPROM_KEYS + (free << 2)));
      if (v == 0xffffffff) {
	break;
      }
      free++;
    }

    if (free >= 250) {
      //fprintf(stdout, "Failed to find free space for key\n");
      reply.result = 3; // NACK, no room

    } else {
      //fprintf(stdout, "Found free space for key at %u (seq: %u)\n", free, payload->seq);

      eeprom_write_dword((uint32_t *)(EEPROM_KEYS+ (free<<2)), payload->hash);
      eeprom_write_word((uint16_t *)EEPROM_SEQ, payload->seq);
      reply.result = 1; // ACK
    }
  }

  sendAnswerTelegram(request, (char *)&reply);
}

void handleDeleteKey(unsigned char *request, struct AddDeleteKeyTelegram *payload) {

  struct AddDeleteKeyAnswerTelegram reply;
  reply.type='D';
  reply.seq=payload->seq;
  reply.result = 0;

  unsigned int currentSeq = eeprom_read_word((uint16_t *)EEPROM_SEQ);
  if (currentSeq != 0xffff && currentSeq > payload->seq) {
    reply.result = 2; // NACK
    //fprintf(stdout, "Ignoring delete of key, because sequence number %u < %u\n", payload->seq, currentSeq);

  } else {
    // Find and nuke the key in EEPROM
    for (int i = 0; i < 250; i++) {
      unsigned long v = eeprom_read_dword((uint32_t *)(EEPROM_KEYS + (i << 2)));
      if (v == payload->hash) {
      	eeprom_write_dword((uint32_t *)(EEPROM_KEYS+ (i<<2)), 0xffffffff);
      	eeprom_write_word((uint16_t *)EEPROM_SEQ, payload->seq);
      	reply.result = 1; // ACK
      	break;
      }
    }

    if (reply.result != 1) {
      //fprintf(stdout, "Failed to find existing key to nuke.\n");
      reply.result = 3; // NACK, not found
    }
  }

  sendAnswerTelegram(request, (char *)&reply);
}

void handleTelegram(unsigned char *request, unsigned char *payload) {
  aes256_context ctx;
  aes256_init(&ctx, AES_KEY);
  aes256_decrypt_ecb(&ctx, payload);

  char *type = (char *)payload;
  //  unsigned int *seq = (unsigned int *)(payload+1);
  unsigned long *crc  = (unsigned long *)(payload+12);
  unsigned long realCRC = crc32((unsigned char *)payload, 12);

  if (*crc == realCRC) {
    //fprintf(stdout, "Got package of type: '%c' seq: %d crc is ok: %lu\n", *type, *seq, realCRC);

    if (*type == 'p') {
      handlePing(request, (struct PingPongTelegram *)payload);

    } else if (*type == 'g') {
      handleGetState(request);

    } else if (*type == 'a') {
      handleAddKey(request, (struct AddDeleteKeyTelegram *)payload);

    } else if (*type == 'd') {
      handleDeleteKey(request, (struct AddDeleteKeyTelegram *)payload);

    } else {
      //fprintf(stdout, "Got package of invalid type: '%c'\n", *type);
    }
  } else {
    //fprintf(stdout, "Got package of type: '%c' seq: %d crc should be: %lu crc is: %lu\n", *type, *seq, *crc, realCRC);
  }
}

void pollComms() {
    static uint8_t buf[BUFFER_SIZE+1];

    uint16_t plen=enc28j60PacketReceive(BUFFER_SIZE, buf);
    buf[BUFFER_SIZE]='\0';
    if (plen){
    	packetloop_icmp_tcp(buf,plen);
      
      if (eth_type_is_ip_and_my_ip(buf,plen) &&
      		buf[IP_PROTO_P]==IP_PROTO_UDP_V &&
      		buf[UDP_DST_PORT_H_P]==(UDP_PORT>>8) &&
      		buf[UDP_DST_PORT_L_P]==(UDP_PORT&0xff)) {
	
      	unsigned char *payload = buf + UDP_DATA_P;
      	unsigned int payloadlen=buf[UDP_LEN_L_P]-UDP_HEADER_LEN;

      	if (payloadlen == 16) {
      		handleTelegram(buf, payload);
      	}
      }
    }
}
