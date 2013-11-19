#include <avr/interrupt.h>
#include <avr/io.h>
#include "defines.h"
#include "wiegand.h"

/*
Pinout:

| Cable        | Signal  | RJ45 |  AVR-pin  |
| UTP          | Wiegand | pin  | KBD | RFID|
+--------------+---------+------+-----+-----+
| Blue pair    | +12V    | 4+5  |     |     |
| Brown pair   | GND     | 7+8  |     |     |
| Orange/white | D1      |  1   | PA4 | PA0 |
| Orange       | D0      |  2   | PA5 | PA1 |
| Green        | Beeper  |  3   | PA6 | PA2 |
| Green/white  | LED     |  6   | PA7 | PA3 |

PA0 = PCINT0 RFID  D1
PA1 = PCINT1 RFID  D0
PA2 = PCINT2
PA3 = PCINT3
PA4 = PCINT4 KDB D1
PA5 = PCINT5 KBD D0
PA6 = PCINT6
PA7 = PCINT7

*/

volatile unsigned char state;
volatile unsigned long rfidFrame;
volatile unsigned char kbdFrame;
volatile unsigned char rfidBits;
volatile unsigned char kbdBits;

volatile unsigned long newRfidValue;
volatile unsigned char kbdValue;
volatile unsigned char rfidReady;
volatile unsigned char kbdReady;

volatile unsigned char timeout;

void initWiegand() {
#if (HAS_WIEGAND)
  timeout = 0;

  // Enable pin change interrupt for the wiegand inputs, switch the led/beeper pins to output and off:
#ifdef WIEGAND_RFID
  PCMSK0 |= _BV(PCINT0) | _BV(PCINT1);
  DDRA  |= _BV(PA2) | _BV(PA3);
  PORTA |= _BV(PA2) | _BV(PA3);
#endif

#ifdef WIEGAND_KBD
  PCMSK0 |= _BV(PCINT4) | _BV(PCINT5);
  DDRA  |= _BV(PA6) | _BV(PA7);
  PORTA |= _BV(PA6) | _BV(PA7);
#endif

  PCICR |= _BV(PCIE0);
  sei();
#endif
}

void greenRFIDLED(char on) {
#ifdef WIEGAND_RFID
  if (!on) {
    PORTA |=  _BV(PA3);
  } else {
    PORTA &=~ _BV(PA3);
  }
#endif
}

void beepRFID(char on) {
#ifdef WIEGAND_RFID
  if (!on) {
    PORTA |=  _BV(PA2);
  } else {
    PORTA &=~ _BV(PA2);
  }
#endif
}

void greenKBDLED(char on) {
#ifdef WIEGAND_KBD
  if (!on) {
    PORTA |=  _BV(PA7);
  } else {
    PORTA &=~ _BV(PA7);
  }
#endif
}

void beepKBD(char on) {
#ifdef WIEGAND_KBD
  if (!on) {
    PORTA |=  _BV(PA6);
  } else {
    PORTA &=~ _BV(PA6);
  }
#endif
}

ISR(PCINT0_vect) {
  unsigned char newState = PINA;

	#ifdef WIEGAND_KBD
  unsigned char kbdBit0  = (state & _BV(PA5)) && !(newState & _BV(PA5));
  unsigned char kbdBit1  = (state & _BV(PA4)) && !(newState & _BV(PA4));
  if (kbdBit0 || kbdBit1) {
    kbdFrame <<= 1;
    kbdFrame |= kbdBit1;
    kbdBits++;
  }
	#endif

	#ifdef WIEGAND_RFID
  unsigned char rfidBit0 = (state & _BV(PA1)) && !(newState & _BV(PA1));
  unsigned char rfidBit1 = (state & _BV(PA0)) && !(newState & _BV(PA0));
  if (rfidBit0 || rfidBit1) {
    rfidFrame <<= 1;
    rfidFrame |= rfidBit1;

    rfidBits++;
  }
	#endif

  state = newState;
  timeout = 0;
}

void pollWiegandTimeout() {
#if (HAS_WIEGAND)
  if (timeout++ > 10) {
    
#ifdef WIEGAND_RFID
    
#ifdef WIEGAND_COMBO
    if (rfidBits == 4) {
      kbdValue=rfidFrame;
      kbdReady=rfidBits;
    } else
#endif
    if (rfidBits == 26) {
      newRfidValue = (rfidFrame>>1) & ~((unsigned long)1<<24); 
      rfidReady = rfidBits;
    }
    rfidBits = 0;
    rfidFrame = 0;
#endif

#ifdef WIEGAND_KBD
    if (kbdBits == 4) {
      kbdValue = kbdFrame;
      kbdReady = kbdBits;
    }
    kbdFrame = 0;
    kbdBits = 0;
#endif
	}
#endif
}

unsigned char isRfidReady() {
  return rfidReady;
}

unsigned long getRfidValue() {
  rfidReady = 0;
  return newRfidValue;
}

unsigned char isKbdReady() {
  return kbdReady;
}

unsigned char getKbdValue() {
  kbdReady = 0;
  return kbdValue;
}



