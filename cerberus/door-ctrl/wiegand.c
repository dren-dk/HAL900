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

void initWiegand() {
  // Enable pin change interrupt for the 4 wiegand inputs
  PCMSK1 = (1<<PCINT8) | (1<<PCINT9) | (1<<PCINT10) | (1<<PCINT11);
  PCICR |= 1<<PCIE1;
}

void greenRFIDLED(char on) {
//TODO  if (!on) {
//TODO    PORTD |= 1<<PD4; 
//TODO  } else {
//TODO    PORTD &=~ (1<<PD4); 
//TODO  }
}

void beepRFID(char on) {
//TODO  if (!on) {
//TODO    PORTD |= 1<<PD5; 
//TODO  } else {
//TODO    PORTD &=~ (1<<PD5); 
//TODO  }
}

void beepKBD(char on) {
//TODO  if (!on) {
//TODO    PORTD |= 1<<PD3; 
//TODO  } else {
//TODO    PORTD &=~ (1<<PD3); 
//TODO  }
}

void greenKBDLED(char on) {
//TODO  if (!on) {
//TODO    PORTD |= 1<<PD2; 
//TODO  } else {
//TODO    PORTD &=~ (1<<PD2); 
//TODO  }
}

void led(char on) {
  if (on) {
    //TODO    PORTB |= 1<<PB1; 
  } else {
    //TODO PORTB &=~ (1<<PB1); 
  }
}

void transistor(char on) {
//TODO  if (on) {
//TODO    PORTD |= 1<<PD7; 
//TODO  } else {
//TODO    PORTD &=~ (1<<PD7); 
//TODO  }
}

void startWiegandTimeout() {
    TCCR2B = 0; // Stop timer    

    TCCR2A = 0;
    TCNT2=0; 
    OCR2A=122; // 10 ms, could probably be 2, but whatever.
    TIMSK2 = 1<<OCIE2A; // Fire interrupt when done

    TCCR2B = 1<<CS00 | 1<<CS02; // Start timer at the slowest clock (1 / 1024)    
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
/*
ISR(TIMER0_COMPA_vect) {
  TCCR2B = 0; // Stop timer

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
*/

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


/*
Bolt cable:

| UTP          | Signal  | AVR |
+--------------+---------+-----+
| Blue         | +12V    |     |
| Blue/white   | +12V    |     |
| Brown        | GND     |     |
| Brown/white  | GND     |     |
| Orange       | Lock    | TODO |
| Orange/white | Door    | TODO |
| Green        | Control | TODO |
| Green/white  |         |     |

Exit push: NC to ground from PB7 (internal pull up)
           available via TP3 on the board.
*/

#if NODE == 1
unsigned char getSensors() {
  unsigned char res = 0;

//TODO  if (PIND & 1<<PD6) {
//    res |= 0x02;
//  }
//TODO  if (PINB & 1<<PB0) {
//TODO    res |= 0x01;
//TODO  }
//TODO  if (PINB & 1<<PB7) {
//TODO    res |= 0x80;
//TODO  }

  return res;
}

#else
unsigned char getSensors() {
  return 0;
}
#endif
