#ifndef DEFINES_H
#define DEFINES_H

#if (F_CPU == 10000000)

// 20 MHz crystal divided down to 10 MHz to stay within the spec for 3.3V
#define CLOCK_PRESCALER 1<<CLKPS0
#define SLEEP_10_MS_COUNT 90


#elif (F_CPU == 20000000)

// 20 MHz crystal, full bore, only valid for 4.5-5.5V
#define CLOCK_PRESCALER 0
#define SLEEP_10_MS_COUNT 180


#elif (F_CPU == 8000000)

// 8 MHz internal RC osc, inaccurate.
#define CLOCK_PRESCALER 0
#define SLEEP_10_MS_COUNT 79


#elif (F_CPU == 12500000)

// 12.5 MHz external clock from enc28j60
#define CLOCK_PRESCALER 0
#define SLEEP_10_MS_COUNT 113

#else
#error No CLOCK_ defined
#endif

#define UART_BAUD  19200

#define UDP_PORT 4747

#include "nodeconfig.h"

#else
#error No NODE defined, don't know how to set up build'
#endif


#endif
