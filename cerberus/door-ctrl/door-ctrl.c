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

#include "sleep.h"
#include "uart.h"

/*
Pinout:

| Cable        | Signal  |  AVR-pin  |
+--------------+---------+-----+-----+
| UTP          | Wiegand | KBD | RFID|
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
  if (on) {
    PORTD |= 1<<PD4; 
  } else {
    PORTD &=~ (1<<PD4); 
  }
}

void greenKBDLED(char on) {
  if (on) {
    PORTD |= 1<<PD2; 
  } else {
    PORTD &=~ (1<<PD2); 
  }
}

int main(void) {
  wdt_enable(WDTO_4S);
  
  DDRD |= 1<<PD2;
  DDRD |= 1<<PD3;
  DDRD |= 1<<PD4;
  DDRD |= 1<<PD5;

  DDRC  &=~ (1<<PC0);
  DDRC  &=~ (1<<PC1);
  DDRC  &=~ (1<<PC3);
  DDRC  &=~ (1<<PC4);

  PORTD |= (1<<PD2); 
  PORTD |= (1<<PD3); 
  PORTD |= (1<<PD4); 
  PORTD |= (1<<PD5); 
  
  greenKBDLED(1);
  uart_init();
  FILE uart_str = FDEV_SETUP_STREAM(uart_putchar, uart_getchar, _FDEV_SETUP_RW);
  stdout = stdin = &uart_str;
  fprintf(stdout, "Power up!\n");
  greenRFIDLED(1);

  
  int loop = 0;
  while(1) {
    greenKBDLED(loop & 1);
    greenRFIDLED(loop++ & 2);

    fprintf(stdout, "Loop: %d\n", loop);

    sleepMs(10);
    wdt_reset();
  }	
}
