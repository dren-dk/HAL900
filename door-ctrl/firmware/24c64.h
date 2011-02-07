#ifndef EE24C64_H
#define EE24C64_H

void eepromInit();
char eepromWrite(unsigned int address, unsigned char data);
int eepromRead(unsigned int address);

#endif
