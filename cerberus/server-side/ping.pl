#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket;
use Crypt::Rijndael;

sub crc32($) {
    my $buffer = shift;
    my @bytes = map {ord($_)} split //, $buffer;
    my $crc = 0;

    for my $byte (@bytes) {
	$crc = $crc ^ $byte;
	for my $j (0..7) {
	    if ($crc & 1) {
		$crc = ($crc>>1) ^ 0xEDB88320;
	    } else {
		$crc = $crc >>1;
	    }
	}
    }
    return $crc;
}

my $ping = pack('csccccccccc', ord('p'), 42, 1, 2, 3, 4, 5, 6, 7, 8, 9);
my $pingCRC = crc32($ping);
print "Calculated crc: $pingCRC\n";
$ping .= pack('L', $pingCRC);

my @key = (0x64, 0x4c, 0x3a, 0xd1, 0x96, 0x7, 0x8f, 0xbc, 0xe7, 0xc, 0x4e, 0x27, 0x20, 0xc2, 0x43, 0xb2, 0x5b, 0xa9, 0x38, 0x7f, 0x15, 0xaa, 0xc, 0x58, 0x83, 0x37, 0x0, 0x20, 0x56, 0x70, 0x8d, 0x59);

my $key = join('', map {chr($_)} @key);
print "Key size: ".length($key)."\n";

my $cipher = Crypt::Rijndael->new($key , Crypt::Rijndael::MODE_ECB() );
my $ep = $cipher->encrypt($ping);

my $s = IO::Socket::INET->new(Proto => 'udp') 
    or die "socket: $@";     # yes, it uses $@ here

my $portaddr = sockaddr_in(4747, inet_aton("10.0.0.1"));
send($s, $ep, 0, $portaddr) == length($ping)
    or die "cannot send: $!";



my $pong;
my $recvaddr = recv($s, $pong, 16, 0)  or die "recv: $!";
my ($portno, $ipaddr) = sockaddr_in($portaddr);
my $host = gethostbyaddr($ipaddr, AF_INET);
print "$host($portno) said $pong\n";
