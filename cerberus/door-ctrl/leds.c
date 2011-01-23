#include <avr/interrupt.h>
#include <avr/io.h>
#include "leds.h"

volatile unsigned char ledsOn;
volatile unsigned char plexCount;

void initLEDs() {
  ledsOn = 0;
  plexCount = 0;
  TCCR2B = 0; // Stop timer    
  
  TCCR2A = 0;
  TCNT2=0; 
  OCR2A=10; // 100 Hz or thereabouts
  TIMSK2 = _BV(OCIE2A); // Fire interrupt when done
  
  TCCR2B = _BV(CS22) | _BV(CS20) | _BV(WGM22);

  sei(); // Enable interrupts!  
}

const char PLEX[6][2] = {
  { _BV(PC4) | _BV(PC5), _BV(PC4) },
  { _BV(PC4) | _BV(PC5), _BV(PC5) },

  { _BV(PC3) | _BV(PC4), _BV(PC3) },
  { _BV(PC3) | _BV(PC4), _BV(PC4) },

  { _BV(PC3) | _BV(PC5), _BV(PC3) },
  { _BV(PC3) | _BV(PC5), _BV(PC5) },
};


ISR(TIMER2_COMPA_vect) {
  // Tristate all pins:
  DDRC  &=~ (_BV(PC3) | _BV(PC4) | _BV(PC5));
  PORTC &=~ (_BV(PC3) | _BV(PC4) | _BV(PC5));

  // Turn on the led we want:
  if (ledsOn & _BV(plexCount)) {
    DDRC  |= PLEX[plexCount][0];
    PORTC |= PLEX[plexCount][1];
  } 

  if (plexCount++ > 5) {
    plexCount = 0;
  }
}

void setLED(unsigned char led, unsigned char on) {
  if (on) {
    ledsOn |= _BV(led);
  } else {
    ledsOn &=~ _BV(led);
  }
}

void setLEDs(unsigned char led) {
  ledsOn = led;
}
