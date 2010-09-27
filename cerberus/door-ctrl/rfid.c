#include "rfid.h"

#include <avr/interrupt.h>
#include <avr/io.h>

#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

unsigned char trigger=1;
unsigned long rfid = 0; 

unsigned long lSum = 0;
unsigned long lCount = 0;

volatile unsigned char state=0;
#define STATE_WAITING 0
#define STATE_DECODING 1
#define STATE_READY 2


char times[256];
unsigned timesInUse =0;

volatile unsigned char dataArrayInUse=0;
volatile unsigned char dataArray[256/8];
#define PUSH_ONE  { dataArray[dataArrayInUse>>3] |=  _BV(dataArrayInUse & 7); if (++dataArrayInUse>=255) state=STATE_DECODING; }
#define PUSH_ZERO { dataArray[dataArrayInUse>>3] &=~ _BV(dataArrayInUse & 7); if (++dataArrayInUse>=255) state=STATE_DECODING; }
#define GET_BIT(x)  (dataArray[(x)>>3] & (_BV((x) & 7)))   

#define CAPTURE_RISING  TCCR1B = _BV(ICNC1) | _BV(CS11) | _BV(CS10) | _BV(ICES1);
#define CAPTURE_FALLING TCCR1B = _BV(ICNC1) | _BV(CS11) | _BV(CS10);

void rfidSetup() {
  // Set up timer 0: The 125 kHz carrierwave output on PD5.
  DDRD |= _BV(PD5);              // OC0B pin as output.
  
  TCCR0A = _BV(WGM01) | _BV(COM0B0); // Count to OCR0B, then reset and toggle OC0B
  TIMSK0 = 0x00;                 // No interrupt on overflow.
  OCR0A = OCR0B = 49;            // Each half-period is 50 clock cycles => 125 kHz
  TCNT0 = 0;                     // Start counting at 0
  TCCR0B = _BV(CS00);            // Raw clock input = 12.5 MHz
  

  // Set up timer 1: Used to measure the demodulated signal on PB0
  DDRB  &=~ (1<<PB0);
  TCCR1A = 0x00;
  TCCR1B = 0x00; 
  TIMSK1 = _BV(ICIE1); // Enable interrupt on input capture
  TCNT1H = 0x0FF; 
  TCNT1L = 0xF8; 
  ACSR = _BV(ACD); // Disable analog comparator;
  CAPTURE_RISING;

  state=STATE_WAITING;
}

// This interrupt is fired on either rising or falling edge of the ICP1 (aka PB0) input
// The value of the TCNT1 register at the time of the edge is captured in the ICR1 register.
ISR(TIMER1_CAPT_vect) {
  TCCR1B = 0; // Stop timer while we work.
  TCNT1 = 0;  // Reset counter to 0

  if (state==STATE_WAITING) {
    if (ICR1 < 200) {
      lSum += ICR1;
      lCount++;
    }
    
    if (ICR1>500) { // Loong pause with no data => reset buffer.
      dataArrayInUse = 0;      
    } 
    
    if (trigger) {
      times[timesInUse++] = ICR1;

      PUSH_ONE;
      if (ICR1 >= 76) {
	PORTD |= _BV(PD4); 
	PUSH_ONE; 
      }	
      CAPTURE_FALLING;
      trigger=0;
      
    } else {
      times[timesInUse++] = -ICR1;

      PUSH_ZERO;
      if (ICR1 >= 76) { // Short = 51, long = 102
	PORTD &=~ _BV(PD4); 
	PUSH_ZERO;
      }
      CAPTURE_RISING;
      trigger=1;
    }
  }
}

void decode(void) {
  unsigned char start_data[21] = { 1,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1 };
  unsigned char id_code[11]    = { 0,0,0,0,0,0,0,0,0,0,0 }; 

  for (int i=0;i<timesInUse;i++) {
    fprintf(stdout, "%d ", times[i]);
  }
  timesInUse = 0;
  fprintf(stdout, "\n");


  /*
  fprintf(stdout, "Decoding %d bits: ", dataArrayInUse);
  for (int i=0;i<dataArrayInUse;i++) {
    if (GET_BIT(i)) {
      fprintf(stdout, "1");
    } else {
      fprintf(stdout, "0");
    }
  }
  fprintf(stdout, "\n");
  */

  unsigned char j=0,i=0;
  for (unsigned char i=0;i<200;i++) {
    for (j=0;j<20;j++) {        
      if ((GET_BIT(i+j)?1:0) != start_data[j])            
        break;
      }
    }

    if (j==20) {
      i += 20; 
      for (unsigned char k = 0;k < 11;k++) {
        unsigned char row_parity = 0; 
        unsigned char temp = 0;
        for (unsigned char foo=0; foo<5; foo++) {
          temp <<= 1; 
          if ((!GET_BIT(i)) && GET_BIT(i+1)) { 
            temp |= 0x01; 
            if (foo < 4) {
	      row_parity += 1; 
	    }

          } else if (GET_BIT(i) && !GET_BIT(i+1)) {
	    temp &= 0xfe;

	  } else {
            state=STATE_WAITING;
            dataArrayInUse=0;
            return;
          } 
          i+=2;
        }

        id_code[k] = (temp >> 1); 
        temp &= 0x01; 
        row_parity %= 2; 

        if (k<10) {
          if (row_parity != temp) {
            state=STATE_WAITING;
            dataArrayInUse=0;
            return;
          } 

        } else {
          if (temp!=0)  {
            state=STATE_WAITING;
            dataArrayInUse=0;     
            return;
          } 
        }
      } 

      for (unsigned char foo = 2;foo < 10;j++) { 
	rfid += (((unsigned long)(id_code[foo])) << (4 * (9 - foo))); 
      }
      state=STATE_READY;
      dataArrayInUse=0;   
      return;      
    }

  state=STATE_WAITING;
  dataArrayInUse=0;  
}


unsigned long rfidValue() {
  if (state == STATE_DECODING) {
    decode();
  }
  if (state == STATE_READY) {
    state = STATE_WAITING;
    return rfid;
  } else {
    return 0;
  }
}

