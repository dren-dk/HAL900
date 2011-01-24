#include "door.h"
#include "defines.h"

#include <avr/interrupt.h>
#include <avr/io.h>

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

void initSensors() {
  
}

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
