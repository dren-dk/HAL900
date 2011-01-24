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

#endif
