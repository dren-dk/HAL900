#ifndef DEFINES_H
#define DEFINES_H

#define CLOCK_125

#if defined(CLOCK_10)

// 20 MHz crystal divided down to 10 MHz to stay within the spec for 3.3V
#define F_CPU 10000000UL
#define CLOCK_PRESCALER 1<<CLKPS0
#define SLEEP_10_MS_COUNT 90


#elif defined(CLOCK_20) 

// 20 MHz crystal, full bore, only valid for 4.5-5.5V
#define F_CPU 20000000UL
#define CLOCK_PRESCALER 0
#define SLEEP_10_MS_COUNT 180


#elif defined(CLOCK_8) 

// 8 MHz internal RC osc, inaccurate.
#define F_CPU 8000000UL
#define CLOCK_PRESCALER 0
#define SLEEP_10_MS_COUNT 79

#elif defined(CLOCK_125) 

// 12.5 MHz external clock from enc28j60
#define F_CPU 12500000UL
#define CLOCK_PRESCALER 0
#define SLEEP_10_MS_COUNT 113

#else
#error No CLOCK_ defined
#endif

#define UART_BAUD  19200

#endif



