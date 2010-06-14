/*********************************************
* vim:sw=8:ts=8:si:et
* To use the above modeline in vim you must have "set modeline" in your .vimrc
* Author: Guido Socher, Copyright: GPL V2
* This program is to test basic functionallity by getting an LED to blink.
* See http://tuxgraphics.org/electronics/
*********************************************/
#include <avr/io.h>
#include <inttypes.h>
#define F_CPU 6250000UL  // 6.25 MHz
#include <util/delay.h>

// set output to VCC, red LED off
#define LEDOFF PORTB|=(1<<PORTB1)
// set output to GND, red LED on
#define LEDON PORTB&=~(1<<PORTB1)
// to test the state of the LED
#define LEDISOFF PORTB&(1<<PORTB1)

int main(void)
{
        /* INITIALIZE */
        // Be very careful with low frequencies (less than 1MHz). Modern and fast programmers 
        // can not supply such low programming clocks. It can lock you out!
        //
        // set the clock prescaler. First write CLKPCE to enable setting of clock the
        // next four instructions.
        CLKPR=(1<<CLKPCE);
        CLKPR=0; // 8 MHZ
        //CLKPR=(1<<CLKPS0); // 4MHz
        //CLKPR=((1<<CLKPS0)|(1<<CLKPS1)); // 1MHz
        //CLKPR=((1<<CLKPS0)|(1<<CLKPS2)); // 0.25MHz

        /* enable PB1 as output */
        DDRB|= (1<<DDB1);

        while (1) {
                    LEDON;
                    _delay_ms(250); 
                    _delay_ms(250);
                    LEDOFF;
                    _delay_ms(250); 
                    _delay_ms(250);
        }
        return(0);
}

