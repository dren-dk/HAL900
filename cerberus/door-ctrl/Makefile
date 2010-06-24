#CC=/opt/avr-gcc-4.2.1/bin/avr-gcc
CC=avr-gcc
CFLAGS=-Os -Wall -pedantic-errors -Werror -mcall-prologues -mmcu=atmega328p -std=c99
OBJ2HEX=avr-objcopy 

AVRDUDE = avrdude -c usbtiny -p m328p

default:
	echo Please use one of the following targets:
	echo make p1: Build and program for node 1
	echo make p2: Build and program for node 2
	echo make p3: Build and program for node 3

p1:
	NODE=1 make program
p2:
	NODE=2 make program
p3:
	NODE=3 make program

program : door-ctrl.hex
	$(AVRDUDE) -e -U flash:w:door-ctrl.hex

rdfuses:
	$(AVRDUDE) -v -q

# see: http://www.engbedded.com/fusecalc/
fuses:
	$(AVRDUDE) -u -v -U lfuse:w:0xc0:m

#%.obj : %.c
#	$(CC) $(CFLAGS) -DNODE=$(NODE) $< -o $@

door-ctrl.obj : door-ctrl.c sleep.c sleep.h uart.c uart.h defines.h net.h ip_config.h ip_arp_udp_tcp.h enc28j60.h ip_arp_udp_tcp.c enc28j60.c aes256.h aes256.c crc32.h crc32.c config.c config.h wiegand.h wiegand.c Makefile
	$(CC) $(CFLAGS) -DNODE=$(NODE) uart.c sleep.c ip_arp_udp_tcp.c enc28j60.c aes256.c crc32.c config.c wiegand.c door-ctrl.c -o $@

%.hex : %.obj
	$(OBJ2HEX) -R .eeprom -O ihex $< $@

clean :
	rm -f *.hex *.obj *.o

