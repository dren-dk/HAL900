#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
 #include <string.h>

/*
  This function eats edges from the signal.
  * Positive numbers are rising edges
  * Negative numbers are falling edges
  * The size of the numbers is the length of time since the last edge.
*/
/*
unsigned char headerLength = 0; // The number of short header bits seen.
char rfidInUse = -1;            // -1 = Looking for the header.
unsigned char rfid[7];          // Temporary storage for the datagram.
#define PUSH_ONE  { rfid[rfidInUse>>3] |=  1<<(rfidInUse & 7);   rfidInUse++; lastBit = 1;}
#define PUSH_ZERO { rfid[rfidInUse>>3] &=~ (1<<(rfidInUse & 7)); rfidInUse++; lastBit = 0;}
#define GET_BIT(x)  (rfid[(x)>>3] & (1<<((x) & 7)))   
unsigned char lastBit = 1;

void addEdge(char length) {
  
  fprintf(stdout, " %d", length);

  if (length > -25 && length < 25) {
    fprintf(stdout, "i");
    return; 
  }

  if (length > 3*76) {
    rfidInUse = -1;
    lastBit = 1;
    headerLength = 0;
    fprintf(stdout, ">");
  }

  char longPulse = (length > 76) || (length < -76);
  if (rfidInUse < 0) {

    if (headerLength == 0) {
      if (length > 0) {
	headerLength = 1;
	fprintf(stdout, "\nS");
      } else {
	fprintf(stdout, "s");
      }

    } else if (longPulse) { // End of header because we met a long pulse somewhere in the data section.
      
      if (headerLength >= 18 && length < 0) { // at least 18 half-waves of 1s in the header and a zero in the data
	fprintf(stdout, "d(%d)",headerLength);
	rfidInUse = 0;
	for (char i=18; i<headerLength; i += 2) {
	  PUSH_ONE;
	}
	PUSH_ZERO;
	
      } else { // Not enough bits for the header, so reset.
	fprintf(stdout, "R\n");
	rfidInUse = -1;
	lastBit = 1;
	headerLength = 0;	
      }

    } else {
      fprintf(stdout, "h");
      headerLength++;
    }

  } else {

    if (longPulse) {      
      if (length > 0) { // Long low period, rising edge => It's a one
	PUSH_ONE;
	fprintf(stdout, "L1\n");
      } else {          // Long high period, falling edge => It's a zero 
	PUSH_ZERO;
	fprintf(stdout, "l0\n");
      }

    } else {
      if (length > 0) {
	if (lastBit) {
	  PUSH_ONE;
	  fprintf(stdout, "S1\n");
	}
      } else {
	if (!lastBit) {
	  PUSH_ZERO;
	  fprintf(stdout, "s0\n");
	}
      }
    }
  }

  // Detect that we are done reading, then check parity and stopbits and parse out to output datatypes.
  if (rfidInUse == 5*8+15) { // 5 bytes of data + 15 bits of parity.
    fprintf(stdout, "Captured datagram:\n"); 
    for (char i=0;i<rfidInUse;i++) {
      if (GET_BIT(i)) {
	fprintf(stdout, "1");
      } else {
	fprintf(stdout, "0");
      } 
      if (i % 5 == 4) {
	fprintf(stdout, "\n");
      }
    }

    // Check row parity:
    char colParity[4];
    for (unsigned char col=0;col<4;col++) {
      colParity[col] = 0;
    }
    
    char errors = 0;
    for (unsigned char row=0;row<10;row++) {
      char rowParity = 0;
      for (unsigned char col=0;col<4;col++) {
	char bit = row*5+col;
	if (GET_BIT(bit)) {
	  rowParity = !rowParity;
	  colParity[col] = !colParity[col];
	}	
      }

      char tp = GET_BIT(row*5+4);
      if (!((tp && rowParity) || (!tp && !rowParity))) {
	fprintf(stdout, "Row parity %d: Failed\n", row);	
	errors++;
      } else {
	fprintf(stdout, "Row parity %d: Ok\n", row);	
      }
    }    
    
    for (unsigned char col=0;col<4;col++) {
      char tp = GET_BIT(5*8+10+col);
      if (!((tp && colParity[col]) || (!tp && !colParity[col]))) {
	fprintf(stdout, "Col parity %d: Failed\n", col);	
	errors++;
      } else {
	fprintf(stdout, "Col parity %d: Ok\n", col);		
      }
    }

    if (GET_BIT(5*8+14)) {
      fprintf(stdout, "Stop bit: Ok\n");      
    } else {	
      fprintf(stdout, "Stop bit: Bad\n");	
      errors++;
    }    
   
    if (!errors) {
      // Parse out the payload bits.
      
    }

    // Ready to go again...
    rfidInUse = -1;
    lastBit = 1;
    headerLength = 0;	  
  }
}
*/


unsigned char catchend=0;
unsigned char dataArrayInUse=0;
unsigned char dataArray[256/8];
#define PUSH_ONE  { dataArray[dataArrayInUse>>3] |=   1<<(dataArrayInUse & 7); if (++dataArrayInUse>=254) catchend=1; }
#define PUSH_ZERO { dataArray[dataArrayInUse>>3] &=~ (1<<(dataArrayInUse & 7));if (++dataArrayInUse>=254) catchend=1; }
#define GET_BIT(x)  (dataArray[(x)>>3] & (1<<((x) & 7)))   

void rfidReset() {
  catchend =0;
  dataArrayInUse=0;
}

void rfidDecode(void) {
  unsigned char start_data[21] = { 1,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1 };
  unsigned char id_code[11]    = { 0,0,0,0,0,0,0,0,0,0,0 }; 
  unsigned int rfid = 0;

  fprintf(stdout, " Got here\n");
  for (unsigned char i=0;i<200;i++) {
    fprintf(stderr, "%d", GET_BIT(i)?1:0);
    
    unsigned char j=0;
    for (j=0;j<21;j++) {        
      if ((GET_BIT(i+j)?1:0) != start_data[j]) {            
	fprintf(stderr, "\n");
        break;
      } else {
	fprintf(stderr, "%d", GET_BIT(i+j)?1:0);
      }
    }

    if (j==20) {
      fprintf(stderr, " Found header\n");
      i += 20; 
      for (unsigned char k = 0;k < 11;k++) {
        unsigned char row_parity = 0; 
        unsigned char temp = 0;
        for (unsigned char foo=0; foo<5; foo++) {
          temp <<= 1; 
          if (!GET_BIT(i) && GET_BIT(i+1)) { 
            temp |= 0x01; 
            if (foo < 4) {
	      row_parity += 1; 
	    }

          } else if (GET_BIT(i) && !GET_BIT(i+1)) {
	    temp &= 0xfe;

	  } else {
	    fprintf(stdout, "Failed 1\n");
	    rfidReset();
            return;
          } 
          i+=2;
        }

        id_code[k] = (temp >> 1); 
        temp &= 0x01; 
        row_parity %= 2; 

        if (k<10) {
          if (row_parity != temp) {
	    fprintf(stdout, "Failed 2\n");
	    rfidReset();
            return;
          } 

        } else {
          if (temp!=0)  {
	    fprintf(stdout, "Failed 3\n");
	    rfidReset();
            return;
          } 
        }
      } 

      for (unsigned char foo = 2;foo < 10;foo++) { 
	rfid += (((unsigned long)(id_code[foo])) << (4 * (9 - foo))); 
      }

      fprintf(stdout, "Found id: %d\n", rfid);
      rfidReset();
      return;
    }
  }
    
  fprintf(stdout, "Nothing found\n");
  rfidReset();
  return;
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

      if (catchend) {
	fprintf(stdout, "Decoding\n");
	rfidDecode();
      }
    }
  }
  fclose(f);
}
