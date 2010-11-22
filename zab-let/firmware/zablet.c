#define F_CPU 8000000UL  // 8 MHz

#include <avr/io.h>             // this contains all the IO port definitions
#include <avr/eeprom.h>
#include <avr/sleep.h>          // definitions for power-down modes
#include <avr/pgmspace.h>       // definitions or keeping constants in program memory
#include <avr/wdt.h>
#include <util/delay.h>

// Shortcut to insert single, non-optimized-out nop
#define NOP __asm__ __volatile__ ("nop")

// Tweak this if neccessary to change timing
#define DELAY_CNT 11

void delay_ten_us(uint16_t us) {
  while (us != 0) {
    for (unsigned char timer=0; timer <= DELAY_CNT; timer++) {
      NOP;
      NOP;
    }
    NOP;
    us--;
  }
}

/*
 This function is needed because we only want to drive the LED pins when they are supposed to be low,
 this means that we make the pins that are supposed to drive leds output and drive them low,
 while the leds that are off will be configured as inputs with the pull-up turn off.
 */
void setLED(unsigned char leds) {
  DDRA = leds;
}

int main() {
    PORTA = 0; // LEDS are active low.
    DDRB = _BV(PB2);
    
    char i = 0;
    char d = 1;
    
    while (1) {

      PORTB &=~ _BV(PB2);
      PORTB |= _BV(PB2);
      
      i += d;
      if (i >= 8) {
	i = 7;
	d = -1;
      }
      if (i < 0) {
	i = 0;
	d = 1;
      }
      
      setLED(1<<i);	

      
      //delay_ten_us(10000);
      delay_ten_us(10);
    }
}
