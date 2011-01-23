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

/* Mapping of generic (aka. legacy) register names to atmega8x names for serial: */
#define UBRRL UBRR1L
#define UCSRB UCSR1B
#define TXEN  TXEN1
#define RXEN  RXEN1
#define UCSRA UCSR1A
#define UDRE  UDRE1
#define UDR   UDR1
#define RXC   RXC1
#define FE    FE1
#define DOR   DOR1



/*
 * Initialize the UART to 8N1.
 */
void uart_init(void)
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
 * Send character c down the UART Tx, wait until tx holding register is empty.
 */
int uart_putchar(char c, FILE *stream) {
  if (c == '\a') {
      fputs("*ring*\n", stderr);
      return 0;
    }

  if (c == '\n') {
    uart_putchar('\r', stream);
  }
  loop_until_bit_is_set(UCSRA, UDRE);
  UDR = c;

  return 0;
}

int uart_getchar(FILE *stream) {
  
  if (UCSRA & 1<<RXC) {
    if (UCSRA & _BV(FE)) {
      return _FDEV_EOF;
    }
    if (UCSRA & _BV(DOR)) {
      return _FDEV_ERR;
    }
	
    return UDR;
  } else {
    return -1000;
  }
}

