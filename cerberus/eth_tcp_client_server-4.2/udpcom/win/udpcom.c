/* This is a vim modeline. Use "set modeline" in .vimrc to enable it
 * vim:sw=8:ts=8:si:et
 * Copyright Guido Socher 
 * License: GPL V2
 * */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
//#include <signal.h>
#include <string.h>
#include <errno.h>
//#include <sys/wait.h>
//#include <sys/types.h>
#include <winsock.h>


static int portnum=1200;

void timeout_handler(int sig_type)
{
        printf("EE: timeout, no answer\n");
        exit(1);
}


void help(){
        printf("udpcom -- send and receive a string with udp\n");
        printf("Usage: udpcom [-h][-p portnumber] commandstring ipaddr\n");
        printf("Options: -h this help\n");
        printf("         -p set the port, default is %d\n",portnum);
        printf("\n");
        printf("commandstring is the string that will be sent to the microcontroller over the network.\n");
        printf("The maximum command length is 45.");
        printf("The program prints any answer strings on stdout.\n");
        exit(0);
}

int main(int argc, char **argv)
{
	/* The following things are used for getopt: */
	extern char *optarg;
	extern int optind;
	extern int opterr;
	int ch;

        u_long dest;
        struct sockaddr_in destaddr,fromaddr,servaddr;
        unsigned int fromlen;
        int sockfd_r;
        int iTimeout = 5000; //milliseconds
        char *buf;
#define RBLEN 500
        char recbuf[RBLEN+1];
        ssize_t recmegslen;


        fromlen = sizeof(fromaddr); // this is important otherwise recvfrom will return "Invalid argument"
	opterr = 0;
	while ((ch = getopt(argc, argv, "hp:")) != -1) {
		switch (ch) {
			case 'p':
				sscanf(optarg,"%d",&portnum);
				break;
			case 'h':
				help();
			case '?':
				fprintf(stderr, "ERROR: No such option. -h for help.\n");
				exit(1);
			/*no default action for case */
			}
	}
	if (optind != argc -2){
		/* exactly two arguments must be given */
		help();
	}
        printf("II: data: %s, ip: %s port: %d\n",argv[optind],argv[optind+1],portnum);
        if (strlen(argv[optind])>45){
                fprintf(stderr,"Error: command too long. Max is 45\n");
                exit(1);
        }
        buf=argv[optind];
        //
	WSADATA wsaData;
	if (WSAStartup(MAKEWORD(1,1),&wsaData)!=0){
		fprintf(stderr,"WSAStartup failed.\n");
		exit(1);
	}
        //
        dest=inet_addr(argv[optind+1]);
        if (dest==INADDR_NONE){
                fprintf(stderr,"Error: %s is not a IP address of format XXX.XXX.XXX.XXX\n",argv[optind+1]);
                exit(1);
        }
        /* initialize the socket address for the destination: */
        destaddr.sin_family = AF_INET;
        destaddr.sin_addr.s_addr = dest;
        destaddr.sin_port = htons(portnum); // dest port
        /* initialize the socket address for this server: */
        servaddr.sin_family = AF_INET;
        servaddr.sin_addr.s_addr = htonl(INADDR_ANY); 
        servaddr.sin_port = htons(portnum); // source port
	memset(&servaddr.sin_zero, 0, sizeof(servaddr.sin_zero)); // zero fill

        if ((sockfd_r = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0)
        {
                perror("open sender socket failed");
                exit(1);
        }
        // non blocking by Craig Stanley:
        setsockopt(sockfd_r, SOL_SOCKET, SO_RCVTIMEO, (char*)&iTimeout, sizeof(iTimeout));
        if (bind(sockfd_r, (struct sockaddr *)&servaddr, sizeof(servaddr))){
                perror("bind socket failed");
                exit(1);
        }
        // we are bound. The parent will get the message even if the sender
	// sends it before we call recvfrom
	/* the closing \0 will be sent as well: */
	if(sendto(sockfd_r,buf,strlen(buf)+1,0,(struct sockaddr *)&destaddr,sizeof(destaddr)) == -1){
		perror("sendto failed");
		exit(1);
	}
        // we will timeout if there is no answer after a few sec
        //signal(SIGALRM, &timeout_handler);
        //alarm(2);
        recmegslen=recvfrom(sockfd_r,recbuf,RBLEN-1,0,(struct sockaddr *)&fromaddr,&fromlen);
        if(recmegslen == -1){
                perror("recvfrom failed");
                exit(1);
        }
        closesocket(sockfd_r);
        recbuf[recmegslen]='\0';
        printf("OK: %s: %s\n",inet_ntoa(fromaddr.sin_addr),recbuf);
	WSACleanup();
        //
        return(0);
}

