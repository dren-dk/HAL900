#ifndef TELEGRAM_H
#define TELEGRAM_H

struct PingPongTelegram {
  char type; // 'p' for ping, 'P' for pong
  unsigned int seq; 
  char payload[9];    
  unsigned long crc32;
} __attribute__ ((packed));

struct StateTelegram {
  char type; // 'G' for reply
  unsigned int seq; 
  unsigned char version;    
  unsigned char sensorState;    
  unsigned char padding[7];
  unsigned long crc32;
} __attribute__ ((packed));

struct AddDeleteKeyTelegram {
  char type; // 'a' for add, 'd' for delete
  unsigned int seq; 
  unsigned long hash;
  unsigned char padding[5];
  unsigned long crc32;
} __attribute__ ((packed));

struct AddDeleteKeyAnswerTelegram {
  char type; // 'A' for add, 'D' for delete
  unsigned int seq; 
  unsigned char result;
  unsigned char padding[8];
  unsigned long crc32;
} __attribute__ ((packed));

struct LogTelegram {
  char type; // 'L' for log message
  unsigned int seq; 
  unsigned char logType; // Power up, Unlock, Rfid, Key, Sensor, Locked 
  union {
    unsigned long hash;   // Unlock
    unsigned long rfid;   // Rfid
    unsigned char sensors; // Sensor
    unsigned char key;    // Key
  } item;
  unsigned char padding[4];
  unsigned long crc32;
} __attribute__ ((packed));

#endif
