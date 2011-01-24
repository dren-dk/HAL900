#include <avr/interrupt.h>
#include <avr/io.h>
#include "wiegand.h"

/*
Pinout:

| Cable        | Signal  | RJ45 |  AVR-pin  |
| UTP          | Wiegand | pin  | KBD | RFID|
+--------------+---------+------+-----+-----+
| Blue pair    | +12V    | 4+5  |     |     |
| Brown pair   | GND     | 7+8  |     |     |
| Orange/white | D1      |  1   | PA0 | PA4 |
| Orange       | D0      |  2   | PA1 | PA5 |
| Green        | LED     |  3   | PA2 | PA6 |
| Green/white  | Beeper  |  6   | PA3 | PA7 |

PA0 = PCINT0 KBD  D1
PA1 = PCINT1 KBD  D0
PA2 = PCINT2
PA3 = PCINT3
PA4 = PCINT4 RFID D1
PA5 = PCINT5 RFID D0
PA6 = PCINT6
PA7 = PCINT7

*/

volatile unsigned char state;
volatile unsigned long rfidFrame;
volatile unsigned char kbdFrame;
volatile unsigned char rfidBits;
volatile unsigned char kbdBits;

volatile unsigned long rfidValue;
volatile unsigned char kbdValue;
volatile unsigned char rfidReady;
volatile unsigned char kbdReady;

volatile unsigned char timeout;

void initWiegand() {
  timeout = 0;

  // Enable pin change interrupt for the 4 wiegand inputs:
  PCMSK1 = _BV(PCINT0) | _BV(PCINT1) | _BV(PCINT2) | _BV(PCINT3);
  PCICR |= _BV(PCIE0);

  DDRA  |= _BV(PA2) | _BV(PA3) | _BV(PA6) | _BV(PA7);
  PORTA |= _BV(PA2) | _BV(PA3) | _BV(PA6) | _BV(PA7);
  sei();
}

void greenRFIDLED(char on) {
  if (!on) {
    PORTA |=  _BV(PA7); 
  } else {
    PORTA &=~ _BV(PA7); 
  }
}

void beepRFID(char on) {
  if (!on) {
    PORTA |=  _BV(PA6); 
  } else {
    PORTA &=~ _BV(PA6); 
  }
}

void beepKBD(char on) {
  if (!on) {
    PORTA |=  _BV(PA2); 
  } else {
    PORTA &=~ _BV(PA2); 
  }
}

void greenKBDLED(char on) {
  if (!on) {
    PORTA |=  _BV(PA3); 
  } else {
    PORTA &=~ _BV(PA3); 
  }
}

ISR(PCINT0_vect) {
  unsigned char newState = PINC;

  unsigned char kbdBit0  = (state & (1<<PC0)) && !(newState & (1<<PC0));
  unsigned char kbdBit1  = (state & (1<<PC1)) && !(newState & (1<<PC1));
  unsigned char rfidBit0 = (state & (1<<PC2)) && !(newState & (1<<PC2));
  unsigned char rfidBit1 = (state & (1<<PC3)) && !(newState & (1<<PC3));

  if (kbdBit0 || kbdBit1) {
    kbdFrame <<= 1;
    kbdFrame |= kbdBit1;
    if (kbdBits++ == 5) {
      kbdValue = kbdFrame;
      kbdReady = kbdBits;
      kbdFrame = 0;
      kbdBits = 0;
    }   
  }

  if (rfidBit0 || rfidBit1) {
    rfidFrame <<= 1;
    rfidFrame |= rfidBit1;

    if (rfidBits++ == 26) {
      rfidValue = (rfidFrame>>1) & ~((unsigned long)1<<24); 
      rfidReady = rfidBits;
      rfidBits = 0;
      rfidFrame = 0;
    }
  }

  state = newState;
  
  timeout = 0;
  PORTB |= _BV(PB0);
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
