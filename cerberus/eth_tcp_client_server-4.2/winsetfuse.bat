@echo -------- begin winsetfuse.bat --------
set AVR=c:\avrgcc
set CC=avr-gcc
set PATH=c:\avrgcc\bin;c:\avrgcc\utils\bin
make -f Makefile fuses
@echo --------  end  --------
pause

