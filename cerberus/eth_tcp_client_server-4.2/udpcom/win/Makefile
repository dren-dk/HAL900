# makefile for windows, written by guido socher
all: udpcom.exe
#-------------------
help: 
	@echo "Usage: make all"
	@echo "or"
	@echo "Usage: make clean"
#-------------------
udpcom.exe: udpcom.o
	gcc -Wall -o udpcom.exe udpcom.o -lwsock32
udpcom.o: udpcom.c
	gcc -Wall -c udpcom.c
#-------------------
clean:
	rm -f *.o udpcom
#-------------------
