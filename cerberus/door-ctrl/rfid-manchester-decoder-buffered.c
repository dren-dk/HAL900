#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

unsigned char rfidBufferInUse=0;
unsigned char rfidBuffer[256/8];
#define PUSH_ONE  { rfidBuffer[rfidBufferInUse>>3] |=   1<<(rfidBufferInUse & 7); ++rfidBufferInUse; }
#define PUSH_ZERO { rfidBuffer[rfidBufferInUse>>3] &=~ (1<<(rfidBufferInUse & 7));++rfidBufferInUse; }
#define GET_BIT(x)  (rfidBuffer[(x)>>3] & (1<<((x) & 7)))   
#define BUFFER_FULL (rfidBufferInUse>=254)
const unsigned char RFID_HEADER[3] = {0xa9, 0xaa, 0xaa};

void rfidReset() {
  rfidBufferInUse=0;
}

/*
  This function will return the first Manchester encoded EM4100 RFID in the bit buffer.
  Notice that the buffer is reset afterwards, no matter what this function finds.
  If no RFID is found then 0 will be returned.

  For a good explanation of how the datagrams are constructed look here:
  http://www.priority1design.com.au/em4100_protocol.html
*/

unsigned int rfidDecode(void) {
  for (unsigned char i=0;i<200;i++) {

    // Check for the header sequence in the buffer.
    unsigned char j=0;
    for (j=0;j<21;j++) {
      unsigned char a = GET_BIT(i+j)?1:0;
      unsigned char b = (RFID_HEADER[j>>3] & (1<<(j&7)))?1:0;
      if (a != b) {
        break;
      }
    }
    if (j != 20) {
      continue; // No header here, try next bit.
    }
    i += 20;  // Skip the header.

    unsigned int rfid = 0;
    unsigned char colParity = 0;
    for (unsigned char rowNumber = 0;rowNumber < 11;rowNumber++) {
      
      unsigned char rowParity = 0; 
      unsigned char row = 0;
      for (unsigned char col=0; col<5; col++) {	  
	unsigned char a = GET_BIT(i);
	unsigned char b = GET_BIT(i+1);
	row <<= 1; 
	if (a < b) { 
	  row |= 0x01;
	  rowParity ^= 1;
	  colParity ^= 16>>col;
	  fprintf(stderr, "1");
	  
	} else if (a > b) {
	  fprintf(stderr, "0");
	  // Nothing to do, newly shifted bits are always 0.
	  
	} else { // No transistion at the middle of the bitperiod => violates Manchester coding.
	  rfidReset(); 
	  return 0;
	} 
	i+=2;
      }
      fprintf(stderr, "\n");

      
      if (rowNumber >= 2 && rowNumber < 10) { // Don't include the first byte nor the col-parity row.
	rfid <<= 4;
	rfid |= row >> 1; // Shift to get rid of row parity
      }
      
      if (rowNumber<10) { // Check parity of all rows, even the ones we ignore.
	if (rowParity) {
	  rfidReset();
	  return 0;
	} 
	
      } else {
	
	// Notice: All good row parities are 0, so they add up to 0 in colParity as well.	
	if (colParity) { 
	  rfidReset();
	  return 0;
	}
	
	if (row & 1) { // Check the stop bit, it's always 0, not a parity of the colParity bits.
	  rfidReset();
	  return 0;
	} 
      }
    } 
    
    rfidReset();
    return rfid; // Yay, all done, the rfid we collected passed all the tests!
  }
    
  rfidReset();
  return 0;
}

int main(int argc, char **argv) {
  FILE *f = fopen("captured-timings.txt", "r");
  
  char buffy[10];
  memset(buffy, 0, 10);
  while (!feof(f)) {
    char ch;
    fread(&ch, 1, 1, f);

    if ((ch >= '0' && ch <= '9') || ch == '-') {
      buffy[strlen(buffy)] = ch;

    } else if (strlen(buffy) > 0) {
      int i = atoi(buffy);
      memset(buffy, 0, 10);
      
      if (i < -76) PUSH_ZERO;
      if (i < -10) PUSH_ZERO;
      if (i > 76) PUSH_ONE;
      if (i > 10) PUSH_ONE;

      if (BUFFER_FULL) {
	fprintf(stdout, "Decoded: %d\n", rfidDecode());
      }
    }
  }
  fclose(f);
}
