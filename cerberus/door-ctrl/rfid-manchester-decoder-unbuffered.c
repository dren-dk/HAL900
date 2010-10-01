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
#define PUSH_ONE  { rfid[rfidInUse>>3] |=  1<<(rfidInUse & 7); rfidInUse++; lastBit = 1;}
#define PUSH_ZERO { rfid[rfidInUse>>3] &=~ (1<<(rfidInUse & 7)); rfidInUse++; lastBit = 0;}
#define GET_BIT(x)  (rfid[(x)>>3] & (1<<((x) & 7)))   
unsigned char lastBit = 1;
char bitTime = 0;

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
    if (edge > 1) {
      headerLength = 1;
      fprintf(stdout, "S");
    } else {
      fprintf(stdout, "_");
    }

  } else if (headerLength < 18) {
    if (edge == ((headerLength & 1)?-1:1)) {
      headerLength++;
      fprintf(stdout, "h");
    } else {
      fprintf(stdout, "E\n");
      headerLength = 0;      
    }

  } else {

    

    if (edge > 1) {  // Long low period, rising edge => It's a one
	PUSH_ONE;
	fprintf(stdout, "L1\n");

    } else if (edge < -1) { // Long high period, falling edge => It's a zero 
	PUSH_ZERO;
	fprintf(stdout, "l0\n");

    } else if (edge > 0) {
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
      } else {
	fprintf(stdout, "Row parity %d: Ok\n", row);	
      }
    }    
    
    for (unsigned char col=0;col<4;col++) {
      char tp = GET_BIT(5*8+10+col);
      if (!((tp && colParity[col]) || (!tp && !colParity[col]))) {
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
    rfidInUse = 0;
    lastBit = 1;
    headerLength = 0;	  
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
