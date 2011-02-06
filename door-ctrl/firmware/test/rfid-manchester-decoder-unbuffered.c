#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

/*
  This file implements an efficient, almost bufferles RFID Manchester decoder.

  You feed it the signal obtained from the ICP interrupt and any detected RFID
  codes become available via the getCurrentRfid and getLastRfid functions.
*/

unsigned char headerLength = 0; // The number of short header bits seen.
char rfidInUse = 0;             // -1 = Looking for the header.
unsigned char rfid[7];          // Temporary storage for the datagram.
char halfBit = 0; // Are we in the middle of a bit?

void pushOne() {
  rfid[rfidInUse>>3] |= 1<<(rfidInUse & 7);
  rfidInUse++;
}

void pushZero() {
  rfidInUse++;
}

char getBit(char x) {
  return rfid[x>>3] & (1<<(x&7));
}

void resetRfidState() {
  headerLength=0;
  rfidInUse=0;
  memset(rfid, 0, 7);
  halfBit=0;
}

/*
  This function eats edges from the signal, each edge is encoded as one of:
  * -2: A long low-period, ending in a rising edge.
  * -1: A short low-period, ending in a rising edge.
  * +1: A short high-period, ending in a falling edge.
  * +2: A long high-period, ending in a falling edge.
*/
void addEdge(char edge) {
  if (headerLength == 0) {
    if (edge < -1) {
      headerLength = 1;
    }

  } else if (headerLength < 18-1) {
    if (edge == ((headerLength & 1)?1:-1)) {
      headerLength++;

    } else {
      headerLength = 0;      
    }

  } else {

    if (edge > 1) {
      
      if (halfBit) {
	resetRfidState();

      } else {
	pushZero();
	halfBit = 0;
      }

    } else if (edge < -1) {

      if (halfBit) {
	resetRfidState();
	
      } else {
	pushOne();
	halfBit = 0;
      }

    } else if (edge > 0) {

      if (halfBit) {
	halfBit = 0;
	pushZero();
      } else {
	halfBit = edge;
      }

    } else {
      if (halfBit) {
	halfBit = 0;
	pushOne();
      } else {
	halfBit = edge;
      }
    }
  }

  // Detect that we are done reading, then check parity and stopbits and parse out to output data.
  if (rfidInUse == 5*8+15) { // 5 bytes of data + 15 bits of parity.

    // Check row parity:
    char colParity = 0;
    {
      char bit = 0; // row*5+col;
      for (unsigned char row=0;row<11;row++) {
	char rowParity = 0;
	//	PORTC |= _BV(PC2);
	for (unsigned char col=0;col<5;col++) {
	  if (getBit(bit++)) {
	    rowParity ^= 1;
	    colParity ^= 16>>col;
	  }
	}
	//PORTC &=~ _BV(PC2);
	
	if (row < 10 && rowParity) {
	  resetRfidState();
	  return;
	}
      }    
    }

    if (colParity >> 1) {
      resetRfidState();
      return;
    }

    if (getBit(5*8+14)) {
      resetRfidState();
      return;
    }

    unsigned long output = 0;
    char bit = 10;
    for (unsigned char row=2;row<10;row++) {
      for (unsigned char col=0;col<4;col++) {
	output <<= 1;
	if (getBit(bit++)) {
	  output |= 1;
	}
      }
      bit++; // Skip row parity.
    }
    /*
    PORTC |= _BV(PC2);
    PORTC &=~ _BV(PC2);
    */
    fprintf(stdout, "Got result: %ld\n", output);

    // Ready to go again...
    resetRfidState();
  }
}

/*
  This function eats edges from the signal, each edge is encoded as one of:
  * -2: A long low-period, ending in a rising edge.
  * -1: A short low-period, ending in a rising edge.
  * +1: A short high-period, ending in a falling edge.
  * +2: A long high-period, ending in a falling edge.
*/
void _addEdge(char edge) {

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

    if (edge > 1) {
      
      if (halfBit) {
	fprintf(stdout, " <--- Manchester violation\n");
	resetRfidState();

      } else {
	pushZero();
	fprintf(stdout, "L");
	halfBit = 0;
      }

    } else if (edge < -1) {

      if (halfBit) {
	fprintf(stdout, " <--- Manchester violation\n");
	resetRfidState();
	
      } else {
	pushOne();
	fprintf(stdout, "l");
	halfBit = 0;
      }

    } else if (edge > 0) {

      if (halfBit) {
	halfBit = 0;
	fprintf(stdout, "S");
	pushZero();
      } else {
	halfBit = edge;
	fprintf(stdout, "½");	
      }

    } else {
      if (halfBit) {
	halfBit = 0;
	fprintf(stdout, "s");
	pushOne();
      } else {
	halfBit = edge;
	fprintf(stdout, "½");	
      }
    }
  }

  // Detect that we are done reading, then check parity and stopbits and parse out to output data.
  if (rfidInUse == 5*8+15) { // 5 bytes of data + 15 bits of parity.
    fprintf(stdout, "\nCaptured datagram:\n"); 
    for (char i=0;i<rfidInUse;i++) {
      if (getBit(i)) {
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
	if (getBit(bit)) {
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

    if (getBit(5*8+14)) {
      fprintf(stdout, "Stop bit: Bad\n");	
    } else {	
      fprintf(stdout, "Stop bit: Ok\n");
    }    
   
    unsigned long output = 0;
    char bit = 10;
    for (unsigned char row=2;row<10;row++) {
      for (unsigned char col=0;col<4;col++) {
	output <<= 1;
	if (getBit(bit++)) {
	  output |= 1;
	}
      }
      bit++; // Skip row parity.
    }
    
    fprintf(stdout, "Got result: %ld\n", output);

    // Ready to go again...
    resetRfidState();
  }
}

int main(int argc, char **argv) {
  FILE *f = fopen("hmm.txt", "r");
  //  FILE *f = fopen("captured-timings.txt", "r");
  
  char buffy[10];
  memset(buffy, 0, 10);
  while (!feof(f)) {
    char ch;
    fread(&ch, 1, 1, f);

    if ((ch >= '0' && ch <= '9') || ch == '-') {
      buffy[strlen(buffy)] = ch;

    } else if (strlen(buffy) > 0) {
      int length = atoi(buffy);
      memset(buffy, 0, 10);

      char edge = length;
      /*
      if (length < -60) edge--;
      if (length < -10) edge--;
      if (length > 60) edge++;
      if (length > 10) edge++;
      */
      addEdge(edge);
    }
  }
  fclose(f);
}
