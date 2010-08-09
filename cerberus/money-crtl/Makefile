#CC=/opt/avr-gcc-4.2.1/bin/avr-gcc
CC=avr-gcc
CFLAGS=-Os -Wall -pedantic-errors -Werror -mcall-prologues -mmcu=atmega328p -std=c99
OBJ2HEX=avr-objcopy 

AVRDUDE = avrdude -c usbtiny -p m88

program : money-ctrl.hex
	$(AVRDUDE) -e -U flash:w:money-ctrl.hex

rdfuses:
	$(AVRDUDE) -v -q

# see: http://www.engbedded.com/fusecalc/
fuses:
	$(AVRDUDE) -u -v -U lfuse:w:0xe2:m -U hfuse:w:0xd4:m

#%.obj : %.c
#	$(CC) $(CFLAGS) -DNODE=$(NODE) $< -o $@

money-ctrl.obj : money-ctrl.c sleep.c sleep.h uart.c uart.h defines.h Makefile
	$(CC) $(CFLAGS) -DNODE=$(NODE) uart.c sleep.c money-ctrl.c -o $@

%.hex : %.obj
	$(OBJ2HEX) -R .eeprom -O ihex $< $@

clean :
	rm -f *.hex *.obj *.o

