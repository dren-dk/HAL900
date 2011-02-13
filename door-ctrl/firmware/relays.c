#include <avr/io.h>

#include "relays.h"
#include "defines.h"

void initRelays() {
	DDRC |= _BV(PC6) | _BV(PC7); // Relays
}

void setRelays(unsigned char on) {
	setRelay1(on & 1);
	setRelay2(on & 2);
}

void setRelay2(unsigned char on) {
	if (on) {
		PORTC |= _BV(PC6);
	} else {
		PORTC &=~ _BV(PC6);
	}
}

void setRelay1(unsigned char on) {
	if (on) {
		PORTC |= _BV(PC7);
	} else {
		PORTC &=~ _BV(PC7);
	}
}
