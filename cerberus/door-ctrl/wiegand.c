#include <avr/interrupt.h>
#include <avr/io.h>
#include "wiegand.h"

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

unsigned char state;
unsigned long rfidFrame;
unsigned char kbdFrame;
unsigned char rfidBits;
unsigned char kbdBits;

unsigned long rfidValue;
unsigned char kbdValue;
unsigned char rfidReady;
unsigned char kbdReady;

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


unsigned char isRfidReady() {
  return rfidReady;
}

unsigned long getRfidValue() {
  rfidReady = 0;
  return rfidValue;
}

unsigned char isKbdReady() {
  return kbdReady;
}

unsigned char getKbdValue() {
  kbdReady = 0;
  return kbdValue;
}
