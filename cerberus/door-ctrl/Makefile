#CC=/opt/avr-gcc-4.2.1/bin/avr-gcc
CC=avr-gcc
CFLAGS=-Os -Wall -pedantic-errors -Werror -mcall-prologues -mmcu=atmega328p -std=c99
OBJ2HEX=avr-objcopy 

AVRDUDE = avrdude -c usbtiny -p m328p

program : door-ctrl.hex
	$(AVRDUDE) -e -U flash:w:door-ctrl.hex

rdfuses:
	$(AVRDUDE) -v -q

# see: http://www.engbedded.com/fusecalc/
fuses:
	$(AVRDUDE) -u -v -U lfuse:w:0xc0:m

door-ctrl.obj : door-ctrl.c sleep.c sleep.h uart.c uart.h defines.h net.h ip_config.h ip_arp_udp_tcp.h enc28j60.h ip_arp_udp_tcp.c enc28j60.c Makefile
	$(CC) $(CFLAGS) uart.c sleep.c ip_arp_udp_tcp.c enc28j60.c door-ctrl.c -o $@

%.hex : %.obj
	$(OBJ2HEX) -R .eeprom -O ihex $< $@

clean :
	rm -f *.hex *.obj *.o

