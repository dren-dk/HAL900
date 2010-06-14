/*********************************************
 * vim:sw=8:ts=8:si:et
 * To use the above modeline in vim you must have "set modeline" in your .vimrc
 * Author: Guido Socher
 * Copyright: GPL V2
 * See http://www.gnu.org/licenses/gpl.html
 *
 * Ethernet remote device and sensor
 * UDP and HTTP interface 
 *
 * Chip type           : Atmega88 or Atmega168 or Atmega328 with ENC28J60
 *********************************************/
#include <avr/io.h>
#include <stdlib.h>
#include <string.h>
#include <avr/pgmspace.h>
#include "ip_arp_udp_tcp.h"
#include "websrv_help_functions.h"
#include "enc28j60.h"
#include "timeout.h"
#include "net.h"

// This software is a web server only. 
//
// please modify the following two lines. mac and ip have to be unique
// in your local area network. You can not have the same numbers in
// two devices:
static uint8_t mymac[6] = {0x54,0x55,0x58,0x10,0x00,0x29};
// how did I get the mac addr? Translate the first 3 numbers into ascii is: TUX
static uint8_t myip[4] = {10,0,0,29};
//static uint8_t myip[4] = {192,168,255,100};
// listen port for tcp/www:
#define MYWWWPORT 80
//
// listen port for udp
#define MYUDPPORT 1200

#define BUFFER_SIZE 550
static uint8_t buf[BUFFER_SIZE+1];
static char gStrbuf[25];

// the password string (only the first 5 char checked), (only a-z,0-9,_ characters):
static char password[]="secret"; // must not be longer than 9 char

// set output to VCC, red LED off
#define LEDOFF PORTB|=(1<<PORTB1)
// set output to GND, red LED on
#define LEDON PORTB&=~(1<<PORTB1)
// to test the state of the LED
#define LEDISOFF PORTB&(1<<PORTB1)
// 
uint8_t verify_password(char *str)
{
        // the first characters of the received string are
        // a simple password/cookie:
        if (strncmp(password,str,strlen(password))==0){
                return(1);
        }
        return(0);
}

// analyse the url given
// return values: -1 invalid password
//                -2 no command given but password valid
//                -3 just refresh page
//                0 switch off
//                1 switch on
//                2 favicon.ico
//
//                The string passed to this function will look like this:
//                /password/?s=1 HTTP/1.....
//                /password/?s=0 HTTP/1.....
//                /password HTTP/1.....
int8_t analyse_get_url(char *str)
{
        uint8_t loop=15;
        // the first slash:
        if (*str == '/'){
                str++;
        }else{
                return(-1);
        }
        if (strncmp("favicon.ico",str,11)==0){
                return(2);
        }
        // the password:
        if(verify_password(str)==0){
                return(-1);
        }
        // move forward to the first space or '/'
        while(loop){
                if(*str==' '){
                        // end of url and no slash after password:
                        return(-2);
                }
                if(*str=='/'){
                        // end of password
                        loop=0;
                        continue;
                }
                str++;
                loop--; // do not loop too long
        }
        // str is now something like password?sw=1 or just end of url
        if (find_key_val(str,gStrbuf,5,"sw")){
                if (gStrbuf[0]=='0'){
                        return(0);
                }
                if (gStrbuf[0]=='1'){
                        return(1);
                }
        }
        return(-3);
}

uint16_t http200ok(void)
{
        return(fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\nPragma: no-cache\r\n\r\n")));
}

// answer HTTP/1.0 301 Moved Permanently\r\nLocation: .....\r\n\r\n
// to redirect
// type =0  : http://tuxgraphics.org/c.ico    favicon.ico file
// type =1  : /password/
uint16_t moved_perm(uint8_t *buf,uint8_t type)
{
        uint16_t plen;
        plen=fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 301 Moved Permanently\r\nLocation: "));
        if (type==1){
                plen=fill_tcp_data_p(buf,plen,PSTR("/"));
                plen=fill_tcp_data(buf,plen,password);
                plen=fill_tcp_data_p(buf,plen,PSTR("/"));
        }else{
                plen=fill_tcp_data_p(buf,plen,PSTR("http://tuxgraphics.org/c.ico"));
                //plen=fill_tcp_data_p(buf,plen,PSTR("http://tuxgraphics.org/ico/print.ico"));
        }
        plen=fill_tcp_data_p(buf,plen,PSTR("\r\n\r\nContent-Type: text/html\r\n\r\n"));
        plen=fill_tcp_data_p(buf,plen,PSTR("<h1>301 Moved Permanently</h1>\n"));
        return(plen);
}


// prepare the webpage by writing the data to the tcp send buffer
uint16_t print_webpage(uint8_t *buf,uint8_t on)
{
        uint16_t plen;
        plen=http200ok();
        plen=fill_tcp_data_p(buf,plen,PSTR("<h2>Eth remote switch</h2>\n<pre> "));
        //plen=fill_tcp_data_p(buf,plen,PSTR("<h2>printer switch</h2>\n<pre> "));
        if (on){
                plen=fill_tcp_data_p(buf,plen,PSTR(" <font color=#00FF00>ON</font>"));
                plen=fill_tcp_data_p(buf,plen,PSTR(" <a href=\"./?sw=0\">[switch off]</a>\n"));
        }else{
                plen=fill_tcp_data_p(buf,plen,PSTR("OFF"));
                plen=fill_tcp_data_p(buf,plen,PSTR(" <a href=\"./?sw=1\">[switch on]</a>\n"));
        }
        plen=fill_tcp_data_p(buf,plen,PSTR("\n<a href=\".\">[refresh status]</a>\n"));
        plen=fill_tcp_data_p(buf,plen,PSTR("</pre><hr>tuxgraphics.org\n"));
        return(plen);
}


int main(void){

        
        uint16_t plen;
        uint16_t dat_p;
        uint8_t cmd_pos=0;
        int8_t cmd;
        uint8_t payloadlen=0;
        char str[20];
        char cmdval;
        
        // set the clock speed to "no pre-scaler" (8MHz with internal osc or 
        // full external speed)
        // set the clock prescaler. First write CLKPCE to enable setting of clock the
        // next four instructions.
        CLKPR=(1<<CLKPCE); // change enable
        CLKPR=0; // "no pre-scaler"
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
        
        DDRB|= (1<<DDB1); // enable PB1, LED as output 
        // the transistor on PD7:
        DDRD|= (1<<DDD7);
        PORTD &= ~(1<<PORTD7);// transistor off
        
        //init the web server ethernet/ip layer:
        init_ip_arp_udp_tcp(mymac,myip,MYWWWPORT);

        while(1){

                // handle ping and wait for a tcp packet
                plen=enc28j60PacketReceive(BUFFER_SIZE, buf);
                buf[BUFFER_SIZE]='\0';
                dat_p=packetloop_icmp_tcp(buf,plen);

                if(dat_p==0){
                        // check if udp otherwise continue
                        goto UDP;
                }
                // toggle led everytime we get a http request        
                if (LEDISOFF){
                        LEDON;
                }else{
                        LEDOFF;
                }
                if (strncmp("GET ",(char *)&(buf[dat_p]),4)!=0){
                        // head, post and other methods:
                        //
                        // for possible status codes see:
                        // http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
                        plen=http200ok();
                        plen=fill_tcp_data_p(buf,plen,PSTR("<h1>200 OK</h1>"));
                        goto SENDTCP;
                }
                if (strncmp("/ ",(char *)&(buf[dat_p+4]),2)==0){
                        plen=http200ok();
                        plen=fill_tcp_data_p(buf,plen,PSTR("<p>Usage: http://host_or_ip/password</p>\n"));
                        goto SENDTCP;
                }
                cmd=analyse_get_url((char *)&(buf[dat_p+4]));
                // for possible status codes see:
                // http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html
                if (cmd==-1){
                        plen=fill_tcp_data_p(buf,0,PSTR("HTTP/1.0 401 Unauthorized\r\nContent-Type: text/html\r\n\r\n<h1>401 Unauthorized</h1>"));
                        goto SENDTCP;
                }
                if (cmd==1){
                        PORTD|= (1<<PORTD7);// transistor on
                }
                if (cmd==0){
                        PORTD &= ~(1<<PORTD7);// transistor off
                }
                if (cmd==2){
                        // favicon:
                        plen=moved_perm(buf,0);
                        goto SENDTCP;
                }
                if (cmd==-2){
                        // redirect to the right base url (e.g add a trailing slash):
                        plen=moved_perm(buf,1);
                        goto SENDTCP;
                }
                // if (cmd==-2) or any other value
                // just display the status:
                plen=print_webpage(buf,(PORTD & (1<<PORTD7)));
                //
SENDTCP:
                www_server_reply(buf,plen); // send data
                continue;

                // tcp port www end
                // -------------------------------
                // udp start, we listen on udp port 1200=0x4B0
UDP:
                // check if ip packets are for us:
                if(eth_type_is_ip_and_my_ip(buf,plen)==0){
                        continue;
                }
                if (buf[IP_PROTO_P]==IP_PROTO_UDP_V&&buf[UDP_DST_PORT_H_P]==(MYUDPPORT>>8)&&buf[UDP_DST_PORT_L_P]==(MYUDPPORT&0xff)){
                        payloadlen=buf[UDP_LEN_L_P]-UDP_HEADER_LEN;
                        // you must sent a string starting with v
                        // e.g udpcom version 10.0.0.24
                        if (verify_password((char *)&(buf[UDP_DATA_P]))){
                                // find the first comma which indicates 
                                // the start of a command:
                                cmd_pos=0;
                                while(cmd_pos<payloadlen){
                                        cmd_pos++;
                                        if (buf[UDP_DATA_P+cmd_pos]==','){
                                                cmd_pos++; // put on start of cmd
                                                break;
                                        }
                                }
                                // a command is one char and a value. At
                                // least 3 characters long. It has an '=' on
                                // position 2:
                                if (cmd_pos<2 || cmd_pos>payloadlen-3 || buf[UDP_DATA_P+cmd_pos+1]!='='){
                                        strcpy(str,"e=no_cmd");
                                        goto ANSWER;
                                }
                                // supported commands are
                                // t=1 t=0 t=?
                                if (buf[UDP_DATA_P+cmd_pos]=='t'){
                                        cmdval=buf[UDP_DATA_P+cmd_pos+2];
                                        if(cmdval=='1'){
                                                PORTD|= (1<<PORTD7);// transistor on
                                                strcpy(str,"t=1");
                                                goto ANSWER;
                                        }else if(cmdval=='0'){
                                                PORTD &= ~(1<<PORTD7);// transistor off
                                                strcpy(str,"t=0");
                                                goto ANSWER;
                                        }else if(cmdval=='?'){
                                                if (PORTD & (1<<PORTD7)){
                                                        strcpy(str,"t=1");
                                                        goto ANSWER;
                                                }
                                                strcpy(str,"t=0");
                                                goto ANSWER;
                                        }
                                }
                                strcpy(str,"e=inv_cmd");
                                goto ANSWER;
                        }
                        strcpy(str,"e=inv_pw");
ANSWER:
                        make_udp_reply_from_request(buf,str,strlen(str),MYUDPPORT);
                }
        }
        return (0);
}
