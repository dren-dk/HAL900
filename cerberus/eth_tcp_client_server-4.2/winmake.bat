REM *** you need to edit this file and adapt it to your WinAVR 
REM *** installation. E.g replace c:\WinAVR by c:\WinAVR-20090313
@echo -------- begin --------

set AVR=c:\WinAVR

set CC=avr-gcc

set PATH=c:\WinAVR\bin;c:\WinAVR\utils\bin

make -f Makefile

@echo --------  end  --------
pause
