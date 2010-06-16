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

#define BUFFER_SIZE 550
#define MYUDPPORT 4747

int main(void) {
  wdt_enable(WDTO_4S);

  char id = 42; // TODO: Read this from EEPROM?
  uint8_t mymac[6] = {0x42,0x42,0x42,0x10,0x00, id};
  uint8_t myip[4]  = {10,0,0,id};

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
  DDRC  &=~ (1<<PC3);
  DDRC  &=~ (1<<PC4);

  greenKBDLED(1);
  uart_init();
  FILE uart_str = FDEV_SETUP_STREAM(uart_putchar, uart_getchar, _FDEV_SETUP_RW);
  stdout = stdin = &uart_str;
  fprintf(stdout, "Power up!\n");
  greenRFIDLED(1);

  // 0x476 is PHLCON LEDA=links status, LEDB=receive/transmit
  // enc28j60PhyWrite(PHLCON,0b0000 0100 0111 01 10);
  enc28j60PhyWrite(PHLCON,0x476);
  init_ip_arp_udp_tcp(mymac, myip, 0);

  greenKBDLED(0);
  greenRFIDLED(0);

  
  int loop = 0;
  while(1) {
    static uint8_t buf[BUFFER_SIZE+1];

    uint16_t plen=enc28j60PacketReceive(BUFFER_SIZE, buf);
    fprintf(stdout, "Received: %d\n", plen);
    buf[BUFFER_SIZE]='\0';
    unsigned int tcpPacketSize = packetloop_icmp_tcp(buf,plen);
    fprintf(stdout, "tcpPacketSize: %d\n", tcpPacketSize);

    if (!tcpPacketSize){ 
      if (eth_type_is_ip_and_my_ip(buf,plen) && 
	  buf[IP_PROTO_P]==IP_PROTO_UDP_V &&
	  buf[UDP_DST_PORT_H_P]==(MYUDPPORT>>8) &&
	  buf[UDP_DST_PORT_L_P]==(MYUDPPORT&0xff)) {
	
	unsigned int payloadlen=buf[UDP_LEN_L_P]-UDP_HEADER_LEN;
	unsigned char *payload = buf + UDP_DATA_P;
	payload[payloadlen] = 0;
	
	fprintf(stdout, "Got UDP: %s\n", payload);
      }
    }

    loop++;
    greenKBDLED(loop & 1);
    greenRFIDLED(loop & 2);
    led(loop & 4);

    //beepRFID(loop & 4);
    //beepKBD(loop & 8);

    fprintf(stdout, "Loop: %d\n", loop);

    sleepMs(10);
    wdt_reset();
  }	
}
