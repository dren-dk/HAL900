#ifndef WIEGAND_H
#define WIEGANG_H

void initWiegand();

// Control the wiegand outputs
void greenRFIDLED(char on);
void beepRFID(char on);
void beepKBD(char on);
void greenKBDLED(char on);

// Get data from the wiegand devices
unsigned char isRfidReady();
unsigned long getRfidValue();
unsigned char isKbdReady();
unsigned char getKbdValue();

// Yeah, not really wiegand related, but they are nicely out of the way here
void led(char on);
void transistor(char on);
unsigned char getSensors();

#endif
