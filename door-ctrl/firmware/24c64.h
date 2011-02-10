#ifndef EE24C64_H
#define EE24C64_H

void ee24xx_init();
int ee24xx_write_bytes(unsigned int eeaddr, int len, unsigned char *buf);
int ee24xx_read_bytes(unsigned int eeaddr, int len, unsigned char *buf);

#endif
