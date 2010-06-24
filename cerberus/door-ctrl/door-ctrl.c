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


/*
Pinout:

| Cable        | Signal  |  AVR-pin  |
| UTP          | Wiegand | KBD | RFID|
+--------------+---------+-----+-----+
| Blue pair    | +12V    |     |     |
| Brown pair   | GND     |     |     |
| Orange       | D0      | PC0 | PC2 |
| Orange/white | D1      | PC1 | PC3 |
| Green        | LED     | PD2 | PD4 |
| Green/white  | Beeper  | PD3 | PD5 |


PC0 = PCINT8
PC1 = PCINT9
PC2 = PCINT10
PC3 = PCINT11

*/

// We don't really care about unhandled interrupts.
EMPTY_INTERRUPT(__vector_default)

void greenRFIDLED(char on) {
  if (!on) {
    PORTD |= 1<<PD4; 
  } else {
    PORTD &=~ (1<<PD4); 
  }
}

void beepRFID(char on) {
  if (!on) {
    PORTD |= 1<<PD5; 
  } else {
    PORTD &=~ (1<<PD5); 
  }
}

void beepKBD(char on) {
  if (!on) {
    PORTD |= 1<<PD3; 
  } else {
    PORTD &=~ (1<<PD3); 
  }
}

void greenKBDLED(char on) {
  if (!on) {
    PORTD |= 1<<PD2; 
  } else {
    PORTD &=~ (1<<PD2); 
  }
}

void led(char on) {
  if (on) {
    PORTB |= 1<<PB1; 
  } else {
    PORTB &=~ (1<<PB1); 
  }
}

void transistor(char on) {
  if (on) {
    PORTD |= 1<<PD7; 
  } else {
    PORTD &=~ (1<<PD7); 
  }
}

unsigned char state;
unsigned long rfidFrame;
unsigned char kbdFrame;
unsigned char rfidBits;
unsigned char kbdBits;

void startWiegandTimeout() {
    TCCR0B = 0; // Stop timer    

    TCCR0A = 0;
    TCNT0=0; 
    OCR0A=122; // 10 ms, could probably be 2, but whatever.
    TIMSK0 = 1<<OCIE0A; // Fire interrupt when done

    TCCR0B = 1<<CS00 | 1<<CS02; // Start timer at the slowest clock (1 / 1024)    
}

ISR(PCINT1_vect) {
  unsigned char newState = PINC;

  unsigned char kbdBit0  = (state & (1<<PC0)) && !(newState & (1<<PC0));
  unsigned char kbdBit1  = (state & (1<<PC1)) && !(newState & (1<<PC1));
  unsigned char rfidBit0 = (state & (1<<PC2)) && !(newState & (1<<PC2));
  unsigned char rfidBit1 = (state & (1<<PC3)) && !(newState & (1<<PC3));

  if (kbdBit0 || kbdBit1) {
    kbdFrame <<= 1;
    kbdFrame |= kbdBit1;
    kbdBits++;
  }

  if (rfidBit0 || rfidBit1) {
    rfidFrame <<= 1;
    rfidFrame |= rfidBit1;
    rfidBits++;
  }

  state = newState;
  startWiegandTimeout();
}

unsigned long rfidValue;
unsigned char kbdValue;
unsigned char rfidReady;
unsigned char kbdReady;

ISR(TIMER0_COMPA_vect) {
  TCCR0B = 0; // Stop timer

  // Get rid of the first and last bits (parity)
  rfidValue = (rfidFrame>>1) & ~((unsigned long)1<<24); 
  kbdValue = kbdFrame;
  kbdReady = kbdBits;
  rfidReady = rfidBits;

  rfidFrame = 0;
  kbdFrame = 0;
  kbdBits = 0;
  rfidBits = 0;
}

char telegramBuffer[16];
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

  unsigned int dport = request[UDP_SRC_PORT_H_P];
  dport <<= 8;
  dport += request[UDP_SRC_PORT_L_P];

  //unsigned char *dip = request+IP_SRC_P;
  sendAnswerTelegram(request, (char *)&pong);
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

    } else {
      fprintf(stdout, "Got package of invalid type: '%c'\n", *type);
    }  
  } else {
    fprintf(stdout, "Got package of type: '%c' seq: %d crc should be: %lu crc is: %lu\n",
	    *type, *seq, *crc, realCRC);  
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

    loop++;
    // greenKBDLED(loop & 1);
    // greenRFIDLED(loop & 2);
    //led(loop & 4);

    //beepRFID(loop & 4);
    //beepKBD(loop & 8);

    if (kbdReady) {
      kbdReady = 0;
      fprintf(stdout, "kbd:%d\n", kbdValue);
    }

    if (rfidReady) {
      rfidReady = 0;
      fprintf(stdout, "RFID: %ld\n", rfidValue);
    }

    sleepMs(10);
    wdt_reset();
  }	
}
