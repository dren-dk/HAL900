udpcom is a command to send a string over UDP to a given
IP-addr. and port and wait for an answer on a fixed local port
and any local interface.

The actual command syntax depends on the syntax implemented in the 
microcontroller. See the README file one level up for details.

The program has sofar been ported to:
- All versions of Linux
- MAC OSX
- Windows


Note: as of July 2008 this program was modified to use only
one socket for sending and receiving. Origninally udpcom was
a sending program and a receiving program combined into one.
However a proper upd network client should not really work this
way. For backward compatibility reasons we use therefore port 1200
for sending and receiving.
