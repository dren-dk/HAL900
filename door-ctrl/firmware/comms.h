#ifndef COMMS_H_
#define COMMS_H_

extern const uint8_t MYMAC[6];
extern const uint8_t MYIP[4];

/*
  EEPROM memory map:
  0-1: EEPROM_SEQ: Current state sequence number
*/

#define EEPROM_SEQ 0
#define EEPROM_KEYS 23

void initComms();
void pollComms();

void logPowerUp();
void logDeny();
void logLocked();
void logUnlock(unsigned long hash);
void logExit();
void logKey(unsigned char key);
void logRfid(unsigned long rfid);
void logSensors(unsigned char sensors);


#endif /* COMMS_H_ */
