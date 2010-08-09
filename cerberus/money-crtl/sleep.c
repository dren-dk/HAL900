#include <avr/sleep.h>
#include <avr/wdt.h> 
#include <avr/interrupt.h>
#include "defines.h"
#include <util/delay.h>

//-----------------------------------------------------------------------------
// Sleep utility for powering down a little between samples.

// Puts the controller to sleep for about 10ms.
void sleep10ms() {
    // Set the timer to sleep 10 ms and then wake up the mcu with an interrupt.
    TCCR2A = 0;
    TIMSK2 = 1<<OCIE2A;                      // Fire interrupt when done
    TCNT2=0;
    OCR2A=SLEEP_10_MS_COUNT;
    TCCR2B = 1<<CS20 | 1<<CS21 | 1<<CS22; 
    sei();

    // power-down, and wait for the compare interrupt to fire.
    //    set_sleep_mode(SLEEP_MODE_PWR_SAVE);
    sleep_mode();
    sleep_enable();
    sleep_cpu();

    // Stop timer again.
    TCCR2B = 0;
}

// Sleep for at least 10 ms at most sleepms + 10 ms 
void sleepMs(unsigned int sleepms) {
  _delay_ms(1);
  sleepms /= 10;
  do {
    sleep10ms();	
    wdt_reset();
  } while (sleepms--);
}
