#ifndef TELEGRAM_H
#define TELEGRAM_H

struct PingPongTelegram {
  char type; // 'p' for ping, 'P' for pong
  unsigned int seq; 
  char payload[9];    
  unsigned long crc32;
} __attribute__ ((packed));

#endif
