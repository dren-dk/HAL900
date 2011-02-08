#include "24c64.h"
#include "defines.h"

#include <util/delay.h>
#include <avr/io.h>

void eepromInit() {
	TWBR = 7_; // SCL freq = F_CPU / (16+2*TWBR* 4^TWPS)
	TWSR &=~ (_BV(TWPS1) | _BV(TWPS0));

	DDRC |= _BV(PC0) | _BV(PC1);
}

char i2cStart() {
	//Put Start Condition on TWI Bus
	TWCR = _BV(TWINT) | _BV(TWSTA) | _BV(TWEN);

	while (!(TWCR & _BV(TWINT))) {
		// Wait.
	}

	return (TWSR & 0xF8) != 0x08;
}


char i2cWrite(unsigned char value) {
	TWDR = value;

	//Initiate Transfer
	TWCR = _BV(TWINT) | _BV(TWEN);

	//Poll Till Done
	while (!(TWCR & _BV(TWINT))) {
		// Wait.
	}

	//Check status
	return (TWSR & 0xF8) != 0x28;
}

#define I2C_WRITE_OR_RETURN(value, x) {if (i2cWrite(value)) return x;}

void i2cStop() {
	//Put Stop Condition on bus
	TWCR = _BV(TWINT) | _BV(TWEN) | _BV(TWSTO);

	//Wait for STOP to finish
	while (TWCR & _BV(TWSTO)) {
		// Wait.
	}
}


char eepromWrite(unsigned int address, unsigned char data) {

	do {
		if (i2cStart()) {
			return 1;
		}

		//Now write SLA+W
		//EEPROM @ 00h
		TWDR = 0xa0; // 0b10100000;

		//Initiate Transfer
		TWCR = _BV(TWINT) | _BV(TWEN);

		while (!(TWCR & _BV(TWINT))) {
			// Wait...
		}

	} while ((TWSR & 0xF8) != 0x18);

	I2C_WRITE_OR_RETURN(address >> 8, 2)
	I2C_WRITE_OR_RETURN(address & 0xff, 3)
	I2C_WRITE_OR_RETURN(data, 4)

	i2cStop();

	_delay_ms(12);

	return 0;
}

int eepromRead(unsigned int address) {
	//Initiate a Dummy Write Sequence to start Random Read
	do {
		if(i2cStart()) {
			return -1;
		}

		//Now write SLA+W
		//EEPROM @ 00h
		TWDR = 0xa0; // 0b10100000;

		//Initiate Transfer
		TWCR = _BV(TWINT) | _BV(TWEN);

		//Poll Till Done
		while (!(TWCR & _BV(TWINT))) {
			// Wait.
		}

	}while ((TWSR & 0xF8) != 0x18);

	I2C_WRITE_OR_RETURN(address >> 8, -2)
	I2C_WRITE_OR_RETURN(address & 0xff, -3)

	//*************************DUMMY WRITE SEQUENCE END **********************

	//Put Start Condition on TWI Bus
	TWCR = _BV(TWINT) | _BV(TWSTA) | _BV(TWEN);
	while (!(TWCR & _BV(TWINT))) {
		// Wait.
	}

	if ((TWSR & 0xF8) != 0x10) {
		return -4;
	}

	//Now write SLA+R
	//EEPROM @ 00h
	TWDR = 0xa1; // 0b10100001;

	//Initiate Transfer
	TWCR=(1<<TWINT)|(1<<TWEN);

	//Poll Till Done
	while(!(TWCR & (1<<TWINT)));

	//Check status
	if((TWSR & 0xF8) != 0x40) {
		return -5;
	}

	//Now enable Reception of data by clearing TWINT
	TWCR = _BV(TWINT) | _BV(TWEN);

	//Wait till done
	while(!(TWCR & _BV(TWINT))) {
		// Meh, wait.
	}

	//Check status
	if((TWSR & 0xF8) != 0x58) {
		return -6;
	}

	//Read the data
	unsigned char data = TWDR;

	i2cStop();

	return data;
}


