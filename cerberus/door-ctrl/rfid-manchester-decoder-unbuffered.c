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

unsigned char headerLength = 0; // The number of short header bits seen.
char rfidInUse = 0;            // -1 = Looking for the header.
unsigned char rfid[7];          // Temporary storage for the datagram.
#define PUSH_ONE  { rfid[rfidInUse>>3] |=  (1<<(rfidInUse & 7)); rfidInUse++; }
#define PUSH_ZERO { rfidInUse++; }
#define GET_BIT(x)  (rfid[(x)>>3] & (1<<((x) & 7)))   
char halfBit = 0;

#define RFID_RESET {rfidInUse=0; headerLength=0; memset(rfid, 0, 7); halfBit=0; }

void addEdge(char length) {
  
  //  fprintf(stdout, " %d", length);

  char edge = 0;
  if (length < -76) edge--;
  if (length < -10) edge--;
  if (length > 76) edge++;
  if (length > 10) edge++;

  fprintf(stdout, " %d", edge);

  if (!edge) {
    fprintf(stdout, "i");
    return; 
  }

  if (headerLength == 0) {
    if (edge < -1) {
      headerLength = 1;
      fprintf(stdout, "\nH");
    } else {
      fprintf(stdout, "_");
    }

  } else if (headerLength < 18-1) {
    if (edge == ((headerLength & 1)?1:-1)) {
      headerLength++;
      fprintf(stdout, "h");
    } else {
      fprintf(stdout, "E\n");
      headerLength = 0;      
    }

  } else {
    if (rfidInUse==0) {
      fprintf(stdout, "\nD");
    }

    if (edge > 1) {  // Long low period, rising edge => It's a one
      
      if (halfBit) {
	fprintf(stdout, " <--- Manchester violation\n");
	RFID_RESET

      } else {
	PUSH_ZERO;
	fprintf(stdout, "L");
	halfBit = 0;
      }

    } else if (edge < -1) { // Long high period, falling edge => It's a zero 

      if (halfBit) {
	fprintf(stdout, " <--- Manchester violation\n");
	RFID_RESET
	
      } else {
	PUSH_ONE;
	fprintf(stdout, "l");
	halfBit = 0;
      }

    } else if (edge > 0) {

      if (halfBit) {
	halfBit = 0;
	fprintf(stdout, "S");
	PUSH_ZERO;
      } else {
	halfBit = edge;
	fprintf(stdout, "½");	
      }

    } else {
      if (halfBit) {
	halfBit = 0;
	fprintf(stdout, "s");
	PUSH_ONE;
      } else {
	halfBit = edge;
	fprintf(stdout, "½");	
      }
    }
  }

  // Detect that we are done reading, then check parity and stopbits and parse out to output datatypes.
  if (rfidInUse == 5*8+15) { // 5 bytes of data + 15 bits of parity.
    fprintf(stdout, "\nCaptured datagram:\n"); 
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
    char colParity = 0;
    for (unsigned char row=0;row<11;row++) {
      char rowParity = 0;
      for (unsigned char col=0;col<5;col++) {
	char bit = row*5+col;
	if (GET_BIT(bit)) {
	  rowParity ^= 1;
	  colParity ^= 16>>col;
	}	
      }

      if (rowParity) {
	fprintf(stdout, "Row parity %d: Failed\n", row);	
      } else {
	fprintf(stdout, "Row parity %d: Ok\n", row);	
      }
    }    
    
    for (unsigned char col=0;col<5;col++) {
      if (colParity & (16>>col)) {
	fprintf(stdout, "Col parity %d: Failed\n", col);	
      } else {
	fprintf(stdout, "Col parity %d: Ok\n", col);	
      }
    }

    if (GET_BIT(5*8+14)) {
      fprintf(stdout, "Stop bit: Bad\n");	
    } else {	
      fprintf(stdout, "Stop bit: Ok\n");
    }    

    // Ready to go again...
    RFID_RESET
  }
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
      addEdge(i);
    }
  }
  fclose(f);
}
