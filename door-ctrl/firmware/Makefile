PART=atmega324p
F_CPU=20000000

# Parts of boards past:
#PART=atmega168
#PART=atmega328p
#F_CPU=12500000

#PROGRAMMER = usbtiny
PROGRAMMER = jtag2isp -P usb

CC=avr-gcc
CFLAGS=-Os -Wall -pedantic-errors -Werror -mcall-prologues -DF_CPU=${F_CPU} -mmcu=${PART} -std=c99 -Wl,-u,vfprintf -lprintf_min

OBJ2HEX=avr-objcopy 

AVRDUDE = avrdude -c ${PROGRAMMER} -p ${PART}

default:
	@echo Please use one of the following targets:
	@echo make p1: Build and program for node 1
	@echo make p2: Build and program for node 2
	@echo make p3: Build and program for node 3

p1:
	NODE=1 make clean program
p2:
	NODE=2 make clean program
p3:
	NODE=3 make clean program

program : door-ctrl.hex
	$(AVRDUDE) -B 1 -e -U flash:w:door-ctrl.hex
#	sleep 1;
#	../../hal/util/test-sync ${NODE}

rdfuses:
	$(AVRDUDE) -B 100 -v -q

# see: http://www.engbedded.com/fusecalc/
fuses:
#	$(AVRDUDE) -B 100 -u -v -U lfuse:w:0xe0:m External clock from ENC28J60
	$(AVRDUDE) -B 100 -u -v -U lfuse:w:0xce:m -U hfuse:w:0xd9:m -U efuse:w:0xfc:m

jtagfuses:
	$(AVRDUDE) -B 100 -u -v -U lfuse:w:0xce:m -U hfuse:w:0x99:m -U efuse:w:0xfc:m

#%.obj : %.c
#	$(CC) $(CFLAGS) -DNODE=$(NODE) $< -o $@

nodeconfig.h::	
	./nodeconfig.pl ${NODE}

%.obj : %.asm
	avra -fO $< -o $@

door-ctrl.obj : door-ctrl.c uart.c uart.h defines.h net.h ip_config.h ip_arp_udp_tcp.h enc28j60.h ip_arp_udp_tcp.c enc28j60.c aes256.h aes256.c crc32.h crc32.c wiegand.h wiegand.c rfid.c rfid.h leds.h leds.c door.h door.c Makefile nodeconfig.h 24c64.h 24c64.c relays.c relays.h comms.h comms.c
	$(CC) $(CFLAGS) -DNODE=$(NODE) uart.c ip_arp_udp_tcp.c enc28j60.c crc32.c wiegand.c door-ctrl.c rfid.c aes256.c leds.c door.c 24c64.c relays.c comms.c -o $@
	avr-size --mcu=$(PART) -C $@

%.hex : %.obj
	$(OBJ2HEX) -R .eeprom -O ihex $< $@

clean :
	rm -f *.hex *.obj *.o


mtest: rfid-manchester-decoder
	./$<

rfid-manchester-decoder: test/rfid-manchester-decoder-buffered.c
	gcc -std=c99 -Wall -g3 -pedantic-errors -Werror -o $@ $<

utest: rfid-manchester-decoder-unbuffered
	./$<

rfid-manchester-decoder-unbuffered: test/rfid-manchester-decoder-unbuffered.c
	gcc -std=c99 -Wall -g3 -pedantic-errors -Werror -o $@ $<
