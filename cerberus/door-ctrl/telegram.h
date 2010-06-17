#ifndef TELEGRAM_H
#define TELEGRAM_H


struct TelegramFrame {
  char type;
  
    
  unsigned long crc32;
} __attribute__ ((packed));

#endif
