#include "rfid.h"

#include <avr/interrupt.h>
#include <avr/io.h>

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "defines.h"

/*
  This file implements an efficient, almost bufferles RFID Manchester decoder.

  You feed it the signal obtained from the ICP interrupt and any detected RFID
  codes become available via the getCurrentRfid and getLastRfid functions.
*/

volatile unsigned long newRfid = 0;
volatile unsigned char trigger=1;
volatile unsigned char headerLength = 0; // The number of short header bits seen.
volatile char rfidInUse = 0;             // -1 = Looking for the header.
unsigned char rfid[7];          // Temporary storage for the datagram.
volatile char halfBit = 0; // Are we in the middle of a bit?

void pushOne() {
  rfid[rfidInUse>>3] |= 1<<(rfidInUse & 7);
  rfidInUse++;
}

void pushZero() {
  rfidInUse++;
}

char getBit(char x) {
  return rfid[x>>3] & (1<<(x&7));
}

void resetRfidState() {
  headerLength=0;
  rfidInUse=0;
  memset(rfid, 0, 7);
  halfBit=0;
}

/*
  This function eats edges from the signal, each edge is encoded as one of:
  * -2: A long low-period, ending in a rising edge.
  * -1: A short low-period, ending in a rising edge.
  * +1: A short high-period, ending in a falling edge.
  * +2: A long high-period, ending in a falling edge.
*/
void addEdge(char edge) {

  if (headerLength == 0) {
    if (edge < -1) {
      headerLength = 1;
    }

  } else if (headerLength < 18-1) {
    if (edge == ((headerLength & 1)?1:-1)) {
      headerLength++;

    } else {
      headerLength = 0;      
    }

  } else {

    if (edge > 1) {
      
      if (halfBit) {
	resetRfidState();

      } else {
	pushZero();
	halfBit = 0;
      }

    } else if (edge < -1) {

      if (halfBit) {
	resetRfidState();
	
      } else {
	pushOne();
	halfBit = 0;
      }

    } else if (edge > 0) {

      if (halfBit) {
	halfBit = 0;
	pushZero();
      } else {
	halfBit = edge;
      }

    } else {
      if (halfBit) {
	halfBit = 0;
	pushOne();
      } else {
	halfBit = edge;
      }
    }
  }

  // Detect that we are done reading, then check parity and stopbits and parse out to output data.
  if (rfidInUse == 5*8+15) { // 5 bytes of data + 15 bits of parity.

    // Check row parity:
    char colParity = 0;
    {
      char bit = 0; // row*5+col;
      for (unsigned char row=0;row<11;row++) {
	char rowParity = 0;
	//	PORTC |= _BV(PC2);
	for (unsigned char col=0;col<5;col++) {
	  if (getBit(bit++)) {
	    rowParity ^= 1;
	    colParity ^= 16>>col;
	  }
	}
	//PORTC &=~ _BV(PC2);
	
	if (row < 10 && rowParity) {
	  resetRfidState();
	  return;
	}
      }    
    }

    if (colParity >> 1) {
      resetRfidState();
      return;
    }

    if (getBit(5*8+14)) {
      resetRfidState();
      return;
    }

    unsigned long output = 0;
    char bit = 10;
    for (unsigned char row=2;row<10;row++) {
      for (unsigned char col=0;col<4;col++) {
	output <<= 1;
	if (getBit(bit++)) {
	  output |= 1;
	}
      }
      bit++; // Skip row parity.
    }
    /*
    PORTC |= _BV(PC2);
    PORTC &=~ _BV(PC2);
    */
    newRfid = output;

    // Ready to go again...
    resetRfidState();
  }
}


#define CAPTURE_RISING  TCCR1B = _BV(ICNC1) | _BV(CS11) | _BV(CS10) | _BV(ICES1);
#define CAPTURE_FALLING TCCR1B = _BV(ICNC1) | _BV(CS11) | _BV(CS10);

#define VERY_LONG_TIME 500
#define LONG_TIME (76*F_CPU)/12500000UL
#define SHORT_TIME (10*F_CPU)/12500000UL


void rfidSetup() {
  // Set up timer 0: The 125 kHz carrierwave output on OC0A 
  DDRB  |= _BV(PB3);              // OC0A pin as output.

  TCCR0A = _BV(WGM01) | _BV(COM0A0); // Count to OCR0A, then reset and toggle OC0A
  TIMSK0 = 0x00;                 // No interrupt on overflow.
  OCR0A = OCR0B = 79;            // Each half-period is 80 clock cycles => 125 kHz
  TCNT0 = 0;                     // Start counting at 0
  TCCR0B = _BV(CS00);            // Raw clock input = 20 MHz
  
  // Set up timer 1: Used to measure the demodulated signal on ICP
  DDRD  &=~ _BV(PD6);
  TCCR1A = 0x00;
  TCCR1B = 0x00; 
  TIMSK1 = _BV(ICIE1); // Enable interrupt on input capture
  TCNT1H = 0xFF; 
  TCNT1L = 0xF8; 
  ACSR = _BV(ACD); // Disable analog comparator;
  CAPTURE_RISING;

  sei(); // Enable interrupts!
}

// This interrupt is fired on either rising or falling edge of the ICP1 input
// The value of the TCNT1 register at the time of the edge is captured in the ICR1 register.
ISR(TIMER1_CAPT_vect) {
  TCCR1B = 0; // Stop timer while we work.
  TCNT1 = 0;  // Reset counter to 0

  if (ICR1>VERY_LONG_TIME) { // Loong pause with no data => reset buffer.
    resetRfidState();
  } 
 
  if (trigger) {
    if (ICR1 >= LONG_TIME) {
      addEdge(2);
    } else if(ICR1 >= SHORT_TIME) {
      addEdge(1);
    }
    CAPTURE_FALLING;
    trigger=0;
    
  } else {
    if (ICR1 >= LONG_TIME) {
      addEdge(-2);
    } else if(ICR1 >= SHORT_TIME) {
      addEdge(-1);
    }
    CAPTURE_RISING;
    trigger=1;
  }
}

unsigned long rfidValue() { 
  unsigned long res = newRfid;
  newRfid = 0;
  return res;
}

