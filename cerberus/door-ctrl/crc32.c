// CCITT CRC-32 (Autodin II) polynomial:
// X32+X26+X23+X22+X16+X12+X11+X10+X8+X7+X5+X4+X2+X+1

#include <stdio.h>

unsigned long crc32(char *buffer, int length) {
  unsigned long crc = 0xffffffff;
  for (int i=0; i<length; i++) {
    unsigned char byte = *buffer++;
    crc = crc ^ byte;
    for (int j=0; j<8; j++) {
      if (crc & 1) {
	crc = (crc>>1) ^ 0xEDB88320;
      } else {
	crc = crc >>1;
      }
    }
  }
  return crc;
}

unsigned long _crc32(char *buffer, int length) {
  unsigned long crc = 0;
  for (int i=0; i<length; i++) {
    unsigned char byte = *buffer++;
    crc = crc ^ byte;
    crc = crc << 4;

    //    fprintf(stdout, "%lu  %u\n", crc, byte);

  }
  return crc;
}


