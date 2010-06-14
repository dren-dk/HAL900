/*********************************************
 * vim:sw=8:ts=8:si:et
 * To use the above modeline in vim you must have "set modeline" in your .vimrc
 * Author: Guido Socher
 * Copyright: GPL V2
 *
 * Tuxgraphics AVR webserver/ethernet board
 *
 * http://tuxgraphics.org/electronics/
 * Chip type           : Atmega88/168/328 with ENC28J60
 *********************************************/
#include <avr/io.h>
#include <stdlib.h>
#include <string.h>
#include "ip_arp_udp_tcp.h"
#include "enc28j60.h"
#include "timeout.h"
#include "net.h"

// This software is a web server only. 
//
// please modify the following two lines. mac and ip have to be unique
// in your local area network. You can not have the same numbers in
// two devices:
static uint8_t mymac[6] = {0xba,0xbe,0xfa,0xce,0x00,0x42};
// how did I get the mac addr? Translate the first 3 numbers into ascii is: TUX
static uint8_t myip[4] = {10,0,0,29};
//static uint8_t myip[4] = {192,168,2,20};
// listen port for www
#define MYWWWPORT 80
//// listen port for udp
#define MYUDPPORT 1200

#define BUFFER_SIZE 550
static uint8_t buf[BUFFER_SIZE+1];

// set output to VCC, red LED off
#define LEDOFF PORTB|=(1<<PORTB1)
// set output to GND, red LED on
#define LEDON PORTB&=~(1<<PORTB1)
// to test the state of the LED
#define LEDISOFF PORTB&(1<<PORTB1)

uint16_t http200ok(void)
{
        return(fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nPragma: no-cache\r\n\r\n")));
}

int main(void){
        uint16_t dat_p;
        // set the clock prescaler. First write CLKPCE to enable setting of clock the
        // next four instructions.
        CLKPR=(1<<CLKPCE);
        CLKPR=0; // 8 MHZ
        _delay_loop_1(0); // 60us
        
        /*initialize enc28j60*/
        enc28j60Init(mymac);
        enc28j60clkout(2); // change clkout from 6.25MHz to 12.5MHz
        _delay_loop_1(0); // 60us
        
        /* Magjack leds configuration, see enc28j60 datasheet, page 11 */
        // LEDB=yellow LEDA=green
        //
        // 0x476 is PHLCON LEDA=links status, LEDB=receive/transmit
        // enc28j60PhyWrite(PHLCON,0b0000 0100 0111 01 10);
        enc28j60PhyWrite(PHLCON,0x476);

        DDRB|= (1<<DDB1); // LED, enable PB1, LED as output
        LEDOFF;
        
        //init the ethernet/ip layer:
        init_ip_arp_udp_tcp(mymac,myip,MYWWWPORT);

        while(1){
                // handle ping and wait for a tcp packet:
                dat_p=packetloop_icmp_tcp(buf,enc28j60PacketReceive(BUFFER_SIZE, buf));

                // dat_p will be unequal to zero if there is a valid http get 
                if(dat_p==0){
                        // do nothing
                        continue;
                }
                // tcp port 80 begin
                if (strncmp("GET ",(char *)&(buf[dat_p]),4)!=0){
                        // head, post and other methods:
                        //
                        // for possible status codes see:
                        // http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
                        dat_p=http200ok();
                        dat_p=fill_tcp_data_p(buf,dat_p,PSTR("<h1>200 OK</h1>"));
                        goto SENDTCP;
                }
                if (strncmp("/ ",(char *)&(buf[dat_p+4]),2)==0){
                        dat_p=http200ok();
                        dat_p=fill_tcp_data_p(buf,dat_p,PSTR("<p>OK, works great!</p>\n"));
                        goto SENDTCP;
                }
                // all other URLs:
                dat_p=fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 401 Unauthorized\r\nContent-Type: text/html\r\n\r\n<h1>401 Unauthorized</h1>"));
SENDTCP:
                www_server_reply(buf,dat_p); // send web page data
        }
        return (0);
}
