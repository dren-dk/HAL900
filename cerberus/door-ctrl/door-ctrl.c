#include "defines.h"

#include <ctype.h>
#include <inttypes.h>

#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#include <avr/io.h>
#include <util/delay.h>
#include <avr/pgmspace.h>
#include <util/twi.h>
#include <avr/sleep.h>

#include <avr/wdt.h> 
#include <avr/interrupt.h>
#include <avr/eeprom.h> 
#include <avr/pgmspace.h>
#include <util/delay.h>

#include "sleep.h"
#include "uart.h"

#include "ip_arp_udp_tcp.h"
#include "enc28j60.h"
#include "net.h"
#include "aes256.h"
#include "crc32.h"
#include "config.h"
#include "telegram.h"
#include "wiegand.h"

// We don't really care about unhandled interrupts.
EMPTY_INTERRUPT(__vector_default)

/*
  EEPROM memory map:
  0-1: EEPROM_SEQ: Current state sequence number
  
  23-1023: EEPROM_KEYS: 4 bytes per key, unused positions set to 0xffffffff
*/

#define EEPROM_SEQ 0
#define EEPROM_KEYS 23


void sendTelegrams(char *telegram) { // Sends the telegram to the registered servers.

}

void sendAnswerTelegram(unsigned char *request, char *telegram) { // Stomps on telegram and request!

  // Affix crc in the right place.
  *((unsigned long *)(telegram+12)) = crc32((unsigned char*)telegram, 12);
  //  fprintf(stdout, "Sending reply UDP package, crc is: %lu\n", *((unsigned long *)(telegram+12)));

  aes256_context ctx; 
  aes256_init(&ctx, getAESKEY());
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
    fprintf(stdout, "Ignoring write of key, because sequence number %u < %u\n", payload->seq, currentSeq);    
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
      fprintf(stdout, "Failed to find free space for key\n");    
      reply.result = 3; // NACK, no room      

    } else {
      fprintf(stdout, "Found free space for key at %u (seq: %u)\n", free, payload->seq);    
      
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
    fprintf(stdout, "Ignoring delete of key, because sequence number %u < %u\n", payload->seq, currentSeq);    

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
      fprintf(stdout, "Failed to find existing key to nuke.\n");    
      reply.result = 3; // NACK, not found
    }
  }
  
  sendAnswerTelegram(request, (char *)&reply);
}


void handleTelegram(unsigned char *request, unsigned char *payload) {
  aes256_context ctx; 
  aes256_init(&ctx, getAESKEY());
  aes256_decrypt_ecb(&ctx, payload);

  char *type = (char *)payload;
  unsigned int *seq = (unsigned int *)(payload+1);    
  unsigned long *crc  = (unsigned long *)(payload+12);
  unsigned long realCRC = crc32((unsigned char *)payload, 12);
  
  if (*crc == realCRC) {
    fprintf(stdout, "Got package of type: '%c' seq: %d crc is ok: %lu\n", *type, *seq, realCRC);

    if (*type == 'p') {
      handlePing(request, (struct PingPongTelegram *)payload);

    } else if (*type == 'g') {
      handleGetState(request);

    } else if (*type == 'a') {
      handleAddKey(request, (struct AddDeleteKeyTelegram *)payload);

    } else if (*type == 'd') {
      handleDeleteKey(request, (struct AddDeleteKeyTelegram *)payload);

    } else {
      fprintf(stdout, "Got package of invalid type: '%c'\n", *type);
    }  
  } else {
    fprintf(stdout, "Got package of type: '%c' seq: %d crc should be: %lu crc is: %lu\n",
	    *type, *seq, *crc, realCRC);  
  }
}

unsigned long keyHash(unsigned long rfid, unsigned long pin) {
  return rfid ^ (0xffff0000 & (pin << 16)) ^ (0x0000ffff & (pin >> 16));
}


/*
  This is the state-machine that keeps track of the user-interaction
*/

enum UserState {
  IDLE,
  ACTIVE,
  OPEN,
  DENY
};

enum UserState userState;

int active; // 0: idle, 1: rfid is valid, collecting pin
int pinCount; // Number of pin digits entered.
unsigned long pin;
unsigned int idleCount;
unsigned long currentRfid;

void handleKey(unsigned char key) {
  if (userState == ACTIVE) {
    idleCount = 0;

    if (key == 10) { // *
      // Door bell?

    } else if (key == 11) { // #
      // Door bell?
      
    } else { // 0..9

      if (pinCount > 8) {
	userState = DENY;
	// TODO: Send logging info.

      } else {
	pinCount++;
	pin *= 10;	
	pin += key;

	if (pinCount >= 4) {
	  unsigned long hash = keyHash(currentRfid, pin);
	
	  for (int i=0;i<250;i++) {
	    unsigned long v = eeprom_read_dword((uint32_t *)(EEPROM_KEYS + (i << 2)));
	    /*
	    if (v != 0xffffffff) {
	      fprintf(stdout, "Comparing with %d = %ld\n", i, v);  	      
	    }
	    */

	    if (hash == v) {
	      // TODO: Send logging info.

	      fprintf(stdout, "Found hit at %d\n", i);  	      
	      
	      idleCount = 0;
	      userState = OPEN;
	      return;
	    }
	  }
	} 
      }
    } 
  }
}

void handleRFID(unsigned long rfid) {
  
  if (userState == IDLE || userState == DENY) {
    userState = ACTIVE;

    beepRFID(0);
    beepKBD(0);

    pin = 0;
    idleCount = 0;
    pinCount = 0;
    currentRfid = rfid; 
    greenRFIDLED(1);
    led(0);

    fprintf(stdout, "Got RFID: %ld\n", rfid);  
  }
}

void handleTick() {
  if (userState == ACTIVE) {
    idleCount++;
    if (idleCount > 500) {
      userState = DENY;
      idleCount = 0;
      // TODO: Send logging info.
    }

  } else if (userState == DENY) {
    idleCount++;
    beepRFID(idleCount > 100);
    beepKBD(1);
    greenRFIDLED(0);
    greenKBDLED(0);

    if (idleCount > 200) {
      beepRFID(0);
      beepKBD(0);
      userState = IDLE;
    }

  } else if (userState == OPEN) {
    idleCount++;
    greenRFIDLED(1);
    greenKBDLED(1);
    led(1);
    transistor(1);

    if (idleCount > 1000) {
      greenRFIDLED(0);
      greenKBDLED(0);
      led(0);
      transistor(0);
      userState = IDLE;
    }
  }
}


#define BUFFER_SIZE 550
int main(void) {
  wdt_enable(WDTO_4S);

  uint8_t mymac[6] = {0x42,0x42, 10,0,0,NODE};
  uint8_t myip[4]  =            {10,0,0,NODE};

  enc28j60Init(mymac);
  enc28j60clkout(2); // change clkout from 6.25MHz to 12.5MHz
  _delay_loop_1(0); // 60us


  // Outputs:
  DDRD |= 1<<PD2;
  DDRD |= 1<<PD3;
  DDRD |= 1<<PD4;
  DDRD |= 1<<PD5;
  DDRD |= 1<<PD7;
  DDRB |= 1<<PB1;

  // Set all outputs high, both LEDs and beepers are active low.
  PORTD |= (1<<PD2); 
  PORTD |= (1<<PD3); 
  PORTD |= (1<<PD4); 
  PORTD |= (1<<PD5);  

  // Inputs:
  DDRC  &=~ (1<<PC0);
  DDRC  &=~ (1<<PC1);
  DDRC  &=~ (1<<PC2);
  DDRC  &=~ (1<<PC3);

  greenKBDLED(1);
  uart_init();
  FILE uart_str = FDEV_SETUP_STREAM(uart_putchar, uart_getchar, _FDEV_SETUP_RW);
  stdout = stdin = &uart_str;
  fprintf(stdout, "Power up!\n");
  greenRFIDLED(1);

  // Enable pin change interrupt for the 4 wiegand inputs
  PCMSK1 = (1<<PCINT8) | (1<<PCINT9) | (1<<PCINT10) | (1<<PCINT11);
  PCICR |= 1<<PCIE1;
  sei();

  // 0x476 is PHLCON LEDA=links status, LEDB=receive/transmit
  enc28j60PhyWrite(PHLCON,0x476);
  init_ip_arp_udp_tcp(mymac, myip, 0);

  greenKBDLED(0);
  greenRFIDLED(0);
  
  int loop = 0;
  while(1) {
    static uint8_t buf[BUFFER_SIZE+1];

    uint16_t plen=enc28j60PacketReceive(BUFFER_SIZE, buf);
    buf[BUFFER_SIZE]='\0';
    unsigned int tcpPacketSize = packetloop_icmp_tcp(buf,plen);
    if (plen && !tcpPacketSize){ 
      if (eth_type_is_ip_and_my_ip(buf,plen) && 
	  buf[IP_PROTO_P]==IP_PROTO_UDP_V &&
	  buf[UDP_DST_PORT_H_P]==(UDP_PORT>>8) &&
	  buf[UDP_DST_PORT_L_P]==(UDP_PORT&0xff)) {
	
	unsigned int payloadlen=buf[UDP_LEN_L_P]-UDP_HEADER_LEN;
	unsigned char *payload = buf + UDP_DATA_P;

	//	fprintf(stdout, "Handling UDP package of %d bytes\n", payloadlen);
	
	if (payloadlen == 16) {
	  handleTelegram(buf, payload);
	}	
      }
    }

    // greenKBDLED(loop & 1);
    // greenRFIDLED(loop & 2);
    //led(loop & 4);

    //beepRFID(loop & 4);
    //beepKBD(loop & 8);

    if (isKbdReady()) {
      handleKey(getKbdValue());
    }

    if (isRfidReady()) {
      handleRFID(getRfidValue());
    }

    handleTick();

    _delay_ms(10);
    led(loop & 1);
    wdt_reset();
    loop++;
  }	
}
