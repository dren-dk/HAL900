/******************** Sniffer Nano *************************
This is the first vesion source code of Sniffer Nano.It' basic 
on the source code that written by Rainbow Chen.
It implements the use of a microcontroller to read the RFID Tag
and output the card ID.
                                  iteadstudio.com  7/30/2010

Cleaned up the code a bit and corrected some spelling.
           Flemming Frandsen <http://dren.dk/> 15 August 2010

************************************************************/

#include "EEPROM.h"

unsigned char catchend=0;
unsigned char trigger=1;
unsigned char firstTime=0;
unsigned char value;
unsigned long rfid = 0; 
unsigned char command[5];
unsigned char p=0;


unsigned char comState=0;
#define COM_IDLE 0
#define COM_REC 1
#define COM_ACTION 2

unsigned char state=0;
#define STATE_WAITING 0
#define STATE_DECODING 1
#define STATE_PROCESS 2

unsigned char dataArrayInUse=0;
unsigned char dataArray[256]; // TODO: Convert this to a bit field to reduce memory usage to 1/8
#define PUSH_ONE {  dataArray[u8_dataArrayInUse]=0; dataArrayInUse++; if (dataArrayInUse>=255) catchend=1;}
#define PUSH_ZERO { dataArray[u8_dataArrayInUse]=1; dataArrayInUse++; if (dataArrayInUse>=255) catchend=1;}
  

// This interrupt is fired on either rising or falling edge of the analog comparator output
// The value of the TCNT1 register at the time of the edge is captured in the ICR1 register.
ISR(TIMER1_CAPT_vect) {
  TCCR1B = 0; // Stop timer while we work.
  TCNT1 = 0;  // Reset counter to 0
  if (state==STATE_WAITING) {
    if (ICR1>500) {
      dataArrayInUse = 0;
      firstTime=1;
    } 
    
    if (!catchend) {
      if (trigger) { // Not sure if this is needed, can there be two rising edges in a row?
        PUSH_ONE;
	if (ICR1>=3) {
	  PUSH_ONE;
	}	
	TCCR1B=0x85; // Falling edge triggered + Input capture noice canceler=on + clock=clkio/1024 
	trigger=0;
       
      } else {
        PUSH_ZERO;
	if (ICR1>=3) {
          PUSH_ZERO;
        }
	TCCR1B=0xC5; // Rising edge triggered + Input capture noice canceler=on + clock=clkio/1024 
	trigger=1;
      }
    }
  }
}

void setup() {
  setupSystem();
  setupTimer();
  Serial.println("Sniffer Nano F/W v1.1");
}

void loop() {   
  
  switch(state) {
    case STATE_WAITING:
      if (catchend) {
	catchend=0;
	if (firstTime) {
	  state=STATE_DECODING;
	}
      }
      
      switch(comState) {
        case COM_IDLE:
	  if (Serial.available()>0)  comState=COM_REC;
	  break;

        case COM_REC:
	  command[p]=Serial.read();
	  if ((p==0)&&(command[p]=='A')) {
	    p++;
	    comState=COM_IDLE;

	  } else if ((p==1)&&(command[p]=='T')) {
	    p++;
	    comState=COM_IDLE;

	  } else if ((p==2)&&(command[p]=='+')) {
	    p++;
	    comState=COM_IDLE;

	  } else if ((p==3)&&(command[p]=='B')) {
	    p++;
	    comState=COM_IDLE;

	  } else if (p==4) {
	    comState=COM_ACTION;  

	  } else { 
	    p=0 ; 
	    comState=COM_IDLE;
	  }          
	  break;

        case COM_ACTION:
	  value=command[4];
	  if (value<0x03) {                    
	    EEPROM.write(0, value); 
	    Serial.print("OK");                 
	  } else {
	    EEPROM.write(0, 0x04); 
	    Serial.print("ERROR");   
	  }
	  p=0;
	  comState=COM_IDLE;
	  break;

        default:
	  comState=COM_IDLE;
	  p=0;
	  break;
      }       
      break;

    case STATE_DECODING:
      decode();
      break;

    case STATE_PROCESS:
      OutputData();
      firstTime=0;
      break;

    default:
      state=0;
      break;
  }
}


void decode(void) {
  unsigned char start_data[21] = { 1,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1 };
  unsigned char id_code[11]    = { 0,0,0,0,0,0,0,0,0,0,0 }; 

  unsigned char j=0;
  for (unsigned char i=0;i<200;i++) {
    for (j=0;j<20;j++) {        
      if (dataArray[i+j] != start_data[j]) {           
        break;
      }
    }

    if (j==20) {
      i += 20; 
      for (unsigned char k = 0;k < 11;k++) {
        unsigned char row_parity = 0; 
        unsigned char temp = 0;
        for (unsigned char foo=0; foo<5; foo++) {
          temp <<= 1; 
          if ((dataArray[i] == 0) && (dataArray[i+1] == 1)) { 
            temp |= 0x01; 
            if (foo < 4) {
	      row_parity += 1; 
	    }

          } else if ((dataArray[i] == 1) && (dataArray[i+1] == 0)) {
	    temp &= 0xfe;

	  } else {
            state=STATE_WAITING;
            dataArrayInUse=0;
            return;
          } 
          i+=2;
        }

        id_code[k] = (temp >> 1); 
        temp &= 0x01; 
        row_parity %= 2; 

        if (k<10) {
          if (row_parity != temp) {
            state=STATE_WAITING;
            dataArrayInUse=0;
            return;
          } 

        } else {
          if (temp!=0)  {
            state=STATE_WAITING;
            dataArrayInUse=0;     
            return;
          } 
        }
      } 

      for (unsigned char foo = 2;foo < 10;j++) { 
	rfid += (((unsigned long)(id_code[foo])) << (4 * (9 - foo))); 
      }
      state=STATE_PROCESS;   
      return;      
    }
  }
  state=STATE_WAITING;
  dataArrayInUse=0;  
}


void OutputData(void) {
  digitalWrite(2,LOW);
  Serial.println(rfid);
  firstTime=0;
  rfid=0;
  dataArrayInUse=0;
  state=STATE_WAITING;
  digitalWrite(2,HIGH);
}

void setupSystem(void) {
  pinMode(2,OUTPUT);
  digitalWrite(2,HIGH);
  value=EEPROM.read(0);

  if (value==0x03) Serial.begin(4800);
  else if (value==0x04) Serial.begin(9600);
  else if (value==0x05) Serial.begin(115200);
  else Serial.begin(9600);
}

void setupTimer(void) {
  DDRD=0;
  DDRD|=0x20;

  TCCR0A = 0x12;
  TIMSK0 = 0x00;
  OCR0B = 0x03;
  OCR0A = 0x03;
  TCNT0=0;

  TCCR1B = 0x00; 
  TIMSK1|= 0x20;
  TCNT1H = 0x0FF; 
  TCNT1L = 0xF8; 
  TCCR1A = 0x00;

  ACSR|=0x04;

  TCCR1B = 0xC5; 
  TCCR0B = 0x02; 
}
