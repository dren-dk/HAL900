# makefile, written by guido socher
#MCU=atmega168
#DUDECPUTYPE=m168
#MCU=atmega88
#DUDECPUTYPE=m88
MCU=atmega328p
DUDECPUTYPE=m328p
#
# === Edit this and enter the correct device/com-port:
# linux (plug in the avrusb500 and type dmesg to see which device it is):
LOADCMD=avrdude

# mac (plug in the programer and use ls /dev/tty.usbserial* to get the name):
#LOADCMD=avrdude -P /dev/tty.usbserial-A9006MOb

# windows (check which com-port you get when you plugin the avrusb500):
#LOADCMD=avrdude -P COM4

# All operating systems: if you have set the default_serial paramter 
# in your avrdude.conf file correctly then you can just use this
# and you don't need the above -P option:
#LOADCMD=avrdude
# === end edit this
#

PROGRAMMER=usbtiny
LOADARG=-p $(DUDECPUTYPE) -c $(PROGRAMMER) -e -U flash:w:

# If you have a tuxgraphics microcontroller mail account 
# then you can uncommet the following line to compile the
# email client. You will also need to edit test_emailnotify.c
# and add your account ID there.
#EMAIL=haveaccount
# 
#
CC=avr-gcc
OBJCOPY=avr-objcopy
# optimize for size:
CFLAGS=-g -mmcu=$(MCU) -Wall -W -Os -mcall-prologues
#-------------------
.PHONY: test0 all main
#
ifeq ($(EMAIL),haveaccount)
all: test0.hex test_readSiliconRev.hex test_OKworks.hex test_web_client.hex eth_rem_dev_tcp.hex basic_web_server_example.hex test_emailnotify.hex test_twitter.hex test_identi_ca.hex
else
#  test_emailnotify.hex is not part of target "all" because you need an account.
all: test0.hex test_readSiliconRev.hex test_OKworks.hex test_web_client.hex eth_rem_dev_tcp.hex basic_web_server_example.hex test_twitter.hex test_identi_ca.hex
endif
	@echo "done"
#
ifeq ($(EMAIL),haveaccount)
test_emailnotify: test_emailnotify.hex
	@echo "done"
endif
#
eth_rem_dev_tcp: eth_rem_dev_tcp.hex
	@echo "done"
#
main: eth_rem_dev_tcp.hex
	@echo "done"
#
test_identi_ca: test_identi_ca.hex
	@echo "done"
#
test_twitter: test_twitter.hex
	@echo "done"
#
test_web_client: test_web_client.hex
	@echo "done"
#
test0: test0.hex
	@echo "done"
#
basic_web_server_example: basic_web_server_example.hex
	@echo "done"
#
test_OKworks: test_OKworks.hex
	@echo "done"
#
test_readSiliconRev: test_readSiliconRev.hex
	@echo "done"
#
#-------------------
help: 
	@echo "Usage: make all|basic_web_server_example|test0|test_readSiliconRev|test_OKworks|eth_rem_dev_tcp|main|test_web_client|test_emailnotify|test_twitter|test_identi_ca"
	@echo "or"
	@echo "make fuse|rdfuses"
	@echo "or"
	@echo "make load|load_basic_web_server_example|load_test0|load_test_readSiliconRev|test_OKworks|load_eth_rem_dev_tcp|load_test_web_client|load_test_emailnotify"
	@echo "or"
	@echo "Usage: make clean"
	@echo " "
	@echo "The relay remote switch is implemented in main.c and compiles to eth_rem_dev_tcp.hex".
	@echo "To just compile this eth_rem_dev_tcp.hex file you can use: make main".
	@echo " "
	@echo "You have to set the low fuse byte to 0x60 on all new tuxgraphics boards".
	@echo "This can be done with the command (linux/mac if you use avrusb500): make fuse"
#-------------------
eth_rem_dev_tcp.hex: eth_rem_dev_tcp.elf 
	$(OBJCOPY) -R .eeprom -O ihex eth_rem_dev_tcp.elf eth_rem_dev_tcp.hex 
	avr-size eth_rem_dev_tcp.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "

eth_rem_dev_tcp.elf: main.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o
	$(CC) $(CFLAGS) -o eth_rem_dev_tcp.elf -Wl,-Map,eth_rem_dev_tcp.map main.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o
websrv_help_functions.o: websrv_help_functions.c websrv_help_functions.h ip_config.h 
	$(CC) $(CFLAGS) -Os -c websrv_help_functions.c
enc28j60.o: enc28j60.c timeout.h enc28j60.h
	$(CC) $(CFLAGS) -Os -c enc28j60.c
ip_arp_udp_tcp.o: ip_arp_udp_tcp.c net.h enc28j60.h ip_config.h
	$(CC) $(CFLAGS) -Os -c ip_arp_udp_tcp.c
main.o: main.c ip_arp_udp_tcp.h enc28j60.h timeout.h net.h websrv_help_functions.h ip_config.h
	$(CC) $(CFLAGS) -Os -c main.c
#------------------
test0.hex: test0.elf 
	$(OBJCOPY) -R .eeprom -O ihex test0.elf test0.hex 
	avr-size test0.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "
test0.elf: test0.o 
	$(CC) $(CFLAGS) -o test0.elf -Wl,-Map,test0.map test0.o 
test0.o: test0.c 
	$(CC) $(CFLAGS) -Os -c test0.c
#------------------
test_identi_ca.hex: test_identi_ca.elf 
	$(OBJCOPY) -R .eeprom -O ihex test_identi_ca.elf test_identi_ca.hex 
	avr-size test_identi_ca.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "
test_identi_ca.elf: test_identi_ca.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o dnslkup.o
	$(CC) $(CFLAGS) -o test_identi_ca.elf -Wl,-Map,test_identi_ca.map test_identi_ca.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o dnslkup.o
#
test_identi_ca.o: test_identi_ca.c ip_arp_udp_tcp.h net.h enc28j60.h ip_config.h dnslkup.h
	$(CC) $(CFLAGS) -Os -c test_identi_ca.c
#------------------
test_twitter.hex: test_twitter.elf 
	$(OBJCOPY) -R .eeprom -O ihex test_twitter.elf test_twitter.hex 
	avr-size test_twitter.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "
test_twitter.elf: test_twitter.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o dnslkup.o
	$(CC) $(CFLAGS) -o test_twitter.elf -Wl,-Map,test_twitter.map test_twitter.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o dnslkup.o
#
test_twitter.o: test_twitter.c  dnslkup.h ip_arp_udp_tcp.h net.h enc28j60.h ip_config.h
	$(CC) $(CFLAGS) -Os -c test_twitter.c
#------------------
dnslkup.o: dnslkup.c 
	$(CC) $(CFLAGS) -Os -c dnslkup.c
#------------------
ifeq ($(EMAIL),haveaccount)
test_emailnotify.hex: test_emailnotify.elf 
	$(OBJCOPY) -R .eeprom -O ihex test_emailnotify.elf test_emailnotify.hex 
	avr-size test_emailnotify.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "
test_emailnotify.elf: test_emailnotify.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o
	$(CC) $(CFLAGS) -o test_emailnotify.elf -Wl,-Map,test_emailnotify.map test_emailnotify.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o
#
test_emailnotify.o: test_emailnotify.c ip_arp_udp_tcp.h net.h enc28j60.h ip_config.h
	$(CC) $(CFLAGS) -Os -c test_emailnotify.c
endif
#------------------
test_web_client.hex: test_web_client.elf 
	$(OBJCOPY) -R .eeprom -O ihex test_web_client.elf test_web_client.hex 
	avr-size test_web_client.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "
test_web_client.elf: test_web_client.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o dnslkup.o
	$(CC) $(CFLAGS) -o test_web_client.elf -Wl,-Map,test_web_client.map test_web_client.o ip_arp_udp_tcp.o enc28j60.o websrv_help_functions.o dnslkup.o
#
test_web_client.o: test_web_client.c ip_arp_udp_tcp.h net.h enc28j60.h ip_config.h dnslkup.h
	$(CC) $(CFLAGS) -Os -c test_web_client.c
#------------------
basic_web_server_example.hex: basic_web_server_example.elf 
	$(OBJCOPY) -R .eeprom -O ihex basic_web_server_example.elf basic_web_server_example.hex 
	avr-size basic_web_server_example.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "
basic_web_server_example.elf: basic_web_server_example.o enc28j60.o ip_arp_udp_tcp.o
	$(CC) $(CFLAGS) -o basic_web_server_example.elf -Wl,-Map,basic_web_server_example.map basic_web_server_example.o enc28j60.o ip_arp_udp_tcp.o
basic_web_server_example.o: basic_web_server_example.c ip_arp_udp_tcp.h enc28j60.h timeout.h net.h
	$(CC) $(CFLAGS) -Os -c basic_web_server_example.c
#------------------
test_OKworks.hex: test_OKworks.elf 
	$(OBJCOPY) -R .eeprom -O ihex test_OKworks.elf test_OKworks.hex 
	avr-size test_OKworks.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "
test_OKworks.elf: test_OKworks.o enc28j60.o ip_arp_udp_tcp.o
	$(CC) $(CFLAGS) -o test_OKworks.elf -Wl,-Map,test_OKworks.map test_OKworks.o enc28j60.o ip_arp_udp_tcp.o
test_OKworks.o: test_OKworks.c ip_arp_udp_tcp.h enc28j60.h timeout.h net.h
	$(CC) $(CFLAGS) -Os -c test_OKworks.c
#------------------
test_readSiliconRev.hex: test_readSiliconRev.elf 
	$(OBJCOPY) -R .eeprom -O ihex test_readSiliconRev.elf test_readSiliconRev.hex 
	avr-size test_readSiliconRev.elf
	@echo " "
	@echo "Expl.: data=initialized data, bss=uninitialized data, text=code"
	@echo " "
test_readSiliconRev.elf: test_readSiliconRev.o enc28j60.o ip_arp_udp_tcp.o
	$(CC) $(CFLAGS) -o test_readSiliconRev.elf -Wl,-Map,test_readSiliconRev.map test_readSiliconRev.o enc28j60.o ip_arp_udp_tcp.o
test_readSiliconRev.o: test_readSiliconRev.c ip_arp_udp_tcp.h enc28j60.h timeout.h net.h
	$(CC) $(CFLAGS) -Os -c test_readSiliconRev.c
#------------------
load_basic_web_server_example: basic_web_server_example.hex
	$(LOADCMD) $(LOADARG)basic_web_server_example.hex
#
load_test_OKworks: test_OKworks.hex
	$(LOADCMD) $(LOADARG)test_OKworks.hex
#
load_test_readSiliconRev: test_readSiliconRev.hex
	$(LOADCMD) $(LOADARG)test_readSiliconRev.hex
#
load_test_identi_ca: test_identi_ca.hex
	$(LOADCMD) $(LOADARG)test_identi_ca.hex
#
load_test_twitter: test_twitter.hex
	$(LOADCMD) $(LOADARG)test_twitter.hex
#
ifeq ($(EMAIL),haveaccount)
load_test_emailnotify: test_emailnotify.hex
	$(LOADCMD) $(LOADARG)test_emailnotify.hex
endif
#
load_test_web_client: test_web_client.hex
	$(LOADCMD) $(LOADARG)test_web_client.hex
#
load_test0: test0.hex
	$(LOADCMD) $(LOADARG)test0.hex
#------------------
load_eth_rem_dev_tcp: eth_rem_dev_tcp.hex
	$(LOADCMD) $(LOADARG)eth_rem_dev_tcp.hex
#
load: eth_rem_dev_tcp.hex
	$(LOADCMD) $(LOADARG)eth_rem_dev_tcp.hex
load_main: eth_rem_dev_tcp.hex
	$(LOADCMD) $(LOADARG)eth_rem_dev_tcp.hex
#
#-------------------
# Check this with make rdfuses
rdfuses:
	$(LOADCMD) -p $(DUDECPUTYPE) -c $(PROGRAMMER) -v -q
#
fuse:
	@echo "Setting clock source to external clock on pin xtal1"
	@echo "Press crtl-C if you do not want to change the clock source"
	@sleep 2
	$(LOADCMD) -p  $(DUDECPUTYPE) -c $(PROGRAMMER) -u -v -U lfuse:w:0x60:m
#
fuses:
	@echo "Setting clock source to external clock on pin xtal1"
	@echo "Press crtl-C if you do not want to change the clock source"
	@sleep 2
	$(LOADCMD) -p  $(DUDECPUTYPE) -c $(PROGRAMMER) -u -v -U lfuse:w:0x60:m
#-------------------
clean:
	rm -f *.o *.map *.elf test*.hex eth_rem_dev_tcp.hex basic_web_server_example.hex
#-------------------
