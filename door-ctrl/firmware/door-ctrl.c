#include "defines.h"

#include <ctype.h>
#include <inttypes.h>

#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>

#include <avr/io.h>
#include <util/delay.h>
#include <avr/pgmspace.h>
#include <util/twi.h>
#include <avr/sleep.h>

#include <avr/wdt.h> 
#include <avr/interrupt.h>
#include <avr/eeprom.h> 
#include <avr/pgmspace.h>

#include "uart.h"

#include "wiegand.h"
#include "rfid.h"
#include "door.h"

#include "leds.h"
#include "24c64.h"
#include "relays.h"
#include "comms.h"

// We don't really care about unhandled interrupts.
EMPTY_INTERRUPT(__vector_default)


/**********************************************************************************************/
/*
  This is the state-machine that keeps track of the user-interaction
*/

unsigned long keyHash(unsigned long rfid, unsigned long pin) {
  return rfid ^ (0xffff0000 & (pin << 16)) ^ (0x0000ffff & (pin >> 16));
}

enum UserState {
  IDLE,
  ACTIVE,
  OPEN,
  DENY
};

enum UserState userState;

int active; // 0: idle, 1: rfid is valid, collecting pin
int pinCount; // Number of pin digits entered.
unsigned long pin;
unsigned int idleCount;
unsigned long currentRfid;

void handleKey(unsigned char key) {
  logKey(key);
  fprintf(stdout, "Key: %d\n", key);

  if (userState == OPEN || userState == ACTIVE) {
    // Allow the user to cancel pin entry and lock the door by hitting esc
    if (key == 10) { // ESC
      userState = IDLE; 
    }
  }

  if (userState == ACTIVE) {
    idleCount = 0;

    if (key == 10) { // ESC
      userState = IDLE;

    } else if (key == 11) { // ENT
      // Door bell?
      
    } else { // 0..9

      if (pinCount > 8) {
      	userState = DENY;
      	logDeny();

      } else {
      	pinCount++;
      	pin *= 10;
      	pin += key;

      	if (pinCount >= 4) {
	  unsigned long hash = keyHash(currentRfid, pin);
	  
	  for (int i=0;i<250;i++) {
	    unsigned long v = eeprom_read_dword((uint32_t *)(EEPROM_KEYS + (i << 2)));
	    /*
	      if (v != 0xffffffff) {
	      fprintf(stdout, "Comparing with %d = %ld\n", i, v);
	      }
	    */
	    
	    if (hash == v) {
	      logUnlock(hash);
	      
	      //fprintf(stdout, "Found hit at %d\n", i);
	      
	      idleCount = 0;
	      userState = OPEN;
	      return;
	    }
	  }
	}
      }
    } 
  }
}

void handleExit() {
  logExit();
  idleCount = 0;
  userState = OPEN;
  return;
}

void handleRFID(unsigned long rfid) {
  
  logRfid(rfid);

  userState = ACTIVE;
  
  beepRFID(0);
  beepKBD(0);
  
  pin = 0;
  idleCount = 0;
  pinCount = 0;
  currentRfid = rfid; 
  greenRFIDLED(1);
  
  fprintf(stdout, "Got RFID: %ld\n", rfid);
}

void handleTick() {
  if (userState == ACTIVE) {
    idleCount++;

    greenKBDLED(idleCount & 16);

    if (idleCount > 500) {
      greenKBDLED(0);
      logDeny();
      userState = DENY;
      idleCount = 0;
    }

  } else if (userState == DENY) {
    idleCount++;

    beepRFID(1);
    beepKBD(1);

    if (idleCount > 100) {
      greenRFIDLED(0);
      greenKBDLED(0);
      beepRFID(0);
      beepKBD(0);
      userState = IDLE;
    }

  } else if (userState == OPEN) {
    idleCount++;
    greenRFIDLED(1);
    greenKBDLED(1);
    PORTC |= _BV(PC6);

    if (idleCount > 1000) {
      logLocked();
      greenRFIDLED(0);
      greenKBDLED(0);
      PORTC &=~ _BV(PC6);
      userState = IDLE;
    }
  }
}



/**********************************************************************************************/
int main(void) {
  wdt_enable(WDTO_4S);

  uart_init();
#if (USE_ETHERNET)
  fprintf(stdout, "Power up! Node %u, IP: %u.%u.%u.%u  MAC: %u:%u:%u:%u:%u:%u\n",NODE,
		  MYIP[0],MYIP[1],MYIP[2],MYIP[3],
  		  MYMAC[0],MYMAC[1],MYMAC[2],MYMAC[3],MYMAC[4],MYMAC[5]);
#else
  fprintf(stdout, "Power up! Node %u, No Ethernet\n",NODE);
#endif

  initComms();
  initWiegand();
  rfidSetup();
  initLEDs();
  logPowerUp();
  ee24xx_init();
  initRelays();

  int loop = 0;
  unsigned char oldSensors = 0;
  while(1) {
    unsigned char sensors = getSensors();
    if (sensors != oldSensors) {
      oldSensors = sensors;
      logSensors(sensors);
    }


    if (sensors & 0x80) { // Exit button pressed
      handleExit();
    }

    if (isKbdReady()) {
      handleKey(getKbdValue());
    }
    
    if (isRfidReady()) {
      handleRFID(getRfidValue());
    }

    setLEDs((loop >> 4) % 0x3f);
    handleTick();
    pollComms();        

    loop++;
    _delay_ms(10);
    wdt_reset();
  }	
}
