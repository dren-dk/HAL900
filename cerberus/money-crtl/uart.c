/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <joerg@FreeBSD.ORG> wrote this file.  As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return.        Joerg Wunsch
 * ----------------------------------------------------------------------------
 *
 * Stdio demo, UART implementation
 *
 * $Id: uart.c,v 1.1.2.1 2005/12/28 22:35:08 joerg_wunsch Exp $
 */

#include "defines.h"

#include <stdint.h>
#include <stdio.h>

#include <avr/io.h>

#include "uart.h"

/* Mapping of old fashioned register names to atmega8x names for rs232: */
#define UBRRL UBRR0L
#define UCSRB UCSR0B
#define TXEN TXEN0
#define RXEN RXEN0
#define UCSRA UCSR0A
#define UDRE UDRE0
#define UDR UDR0
#define RXC RXC0
#define FE FE0
#define DOR DOR0



/*
 * Initialize the UART to 8N1.
 */
void
uart_init(void)
{
#if F_CPU < 2000000UL && defined(U2X)
  UCSRA = _BV(U2X);             /* improve baud rate error by using 2x clk */
  UBRRL = (F_CPU / (8UL * UART_BAUD)) - 1;
#else
  UBRRL = (F_CPU / (16UL * UART_BAUD)) - 1;
#endif
  UCSRB = _BV(TXEN) | _BV(RXEN); /* tx/rx enable */
}

/*
 * Send character c down the UART Tx, wait until tx holding register
 * is empty.
 */
int uart_putchar(char c, FILE *stream) {
  if (c == '\a')
    {
      fputs("*ring*\n", stderr);
      return 0;
    }

  if (c == '\n')
    uart_putchar('\r', stream);
  loop_until_bit_is_set(UCSRA, UDRE);
  UDR = c;

  return 0;
}

int uart_getchar(FILE *stream) {

    if (UCSRA & 1<<RXC) {
	if (UCSRA & _BV(FE))
	    return _FDEV_EOF;
	if (UCSRA & _BV(DOR))
	    return _FDEV_ERR;
	
	return UDR;
    } else {
	return -1000;
    }
}

