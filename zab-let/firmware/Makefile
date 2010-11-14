PART=attiny84

#PROGRAMMER = usbtiny -P usb
PROGRAMMER = jtag2isp -P usb



CC=avr-gcc
CFLAGS=-Os -Wall -pedantic-errors -Werror -mcall-prologues -mmcu=${PART} -std=c99
OBJ2HEX=avr-objcopy 

AVRDUDE = avrdude -c ${PROGRAMMER} -p ${PART}

default: clean program

program: zablet.hex
	$(AVRDUDE) -e -U flash:w:zablet.hex

rdfuses:
	$(AVRDUDE) -v -q

# see: http://www.engbedded.com/fusecalc/
fuses:
	$(AVRDUDE) -u -v -U lfuse:w:0xfd:m -U hfuse:w:0xdf:m

#%.obj : %.c
#	$(CC) $(CFLAGS) -DNODE=$(NODE) $< -o $@

zablet.obj : zablet.c Makefile
	$(CC) $(CFLAGS) -DNODE=$(NODE) zablet.c -o $@
	avr-size -C $@

%.hex : %.obj
	$(OBJ2HEX) -R .eeprom -O ihex $< $@

clean :
	rm -f *.hex *.obj *.o *.eep

