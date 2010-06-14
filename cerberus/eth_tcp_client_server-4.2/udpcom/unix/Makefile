# makefile, written by guido socher
all: udpcom
#-------------------
help: 
	@echo "Usage: make all"
	@echo "or"
	@echo "Usage: make clean"
#-------------------
udpcom: udpcom.c
	gcc -Wall -o udpcom udpcom.c
	strip udpcom
#-------------------
clean:
	rm -f *.o udpcom
#-------------------
