udpcom for windows
Author: Guido Socher
Corrections by Craig Stanley


This is a wsock 32 port of udpcom

The pre-compiled executable was made under winxp and
should work on many windows variants.

The timeout code is for the socket communication was provided by
Craig Stanley. Guido's original udpcom for windows did not have
any timeout.

Timeout code:
int iTimeout = 5000; //milliseconds
setsockopt(sockfd_r, SOL_SOCKET, SO_RCVTIMEO, (char*)&iTimeout, sizeof(iTimeout));


This code can be compiled e.g with mingw http://www.mingw.org/

E.g like this:
c:\mingw\bin\gcc -Wall -c udpcom.c
c:\mingw\bin\gcc -Wall -o udpcom.exe udpcom.o -lwsock32

You can also install make and use the provided make file.
