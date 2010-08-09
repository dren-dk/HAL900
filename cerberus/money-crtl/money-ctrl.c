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

// We don't really care about unhandled interrupts.
EMPTY_INTERRUPT(__vector_default)


/**********************************************************************************************/
int main(void) {
  wdt_enable(WDTO_4S);

  // Outputs:
  DDRB  |= 1<<PB5; // LED

  while (1) {
    PORTB |= 1<<PB5;  
    PORTB &= ~(1<<PB5);  
  }

  uart_init();
  FILE uart_str = FDEV_SETUP_STREAM(uart_putchar, uart_getchar, _FDEV_SETUP_RW);
  stdout = stdin = &uart_str;
  fprintf(stdout, "Power up!\n");

  int loop = 0;
  while(1) {
    if (loop++ & 1) {
      PORTB |= 1<<PB5;  
    } else {
      PORTB &= !(1<<PB5);  
    }

    _delay_ms(250);
    wdt_reset();
  }	
}
