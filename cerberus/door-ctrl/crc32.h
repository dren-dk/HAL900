#ifndef CRC32_H
#define CRC32_H

// CCITT CRC-32 (Autodin II) polynomial:
// X32+X26+X23+X22+X16+X12+X11+X10+X8+X7+X5+X4+X2+X+1

unsigned long crc32(unsigned long crc, char *buffer, int length);

#endif

