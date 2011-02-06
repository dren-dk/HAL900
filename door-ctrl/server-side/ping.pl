#!/usr/bin/perl
use strict;
use warnings;
use IO::Socket;
use Crypt::Rijndael;
use Data::Dumper;

sub crc32($) {
    my $buffer = shift;
    my @bytes = map {ord($_)} split //, $buffer;
    my $crc = 0xffffffff;

    for my $byte (@bytes) {
	$crc = $crc ^ $byte;
	print "$crc  $byte\n";
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

my $ping = pack('csccccccccc', ord('p'), 420, 1, 2, 3, 4, 5, 6, 7, 8, 9);
my $pingCRC = crc32($ping);
print "Calculated crc: $pingCRC\n";
$ping .= pack('L', $pingCRC);

my @key = (
# TODO: Add AES key here.
);

my $key = join('', map {chr($_)} @key);

my $cipher = Crypt::Rijndael->new($key , Crypt::Rijndael::MODE_ECB() );
my $ep = $cipher->encrypt($ping);

my $s = IO::Socket::INET->new(Proto => 'udp', PeerPort=>4747,
			      PeerAddr=>'10.0.0.1') 
    or die "socket: $@";     # yes, it uses $@ here

$s->send($ep) == length($ping)
    or die "cannot send: $!";

print "Sent ping, waiting for pong...\n";

my $pong;
my $recvaddr = $s->recv($pong, 160)  or die "recv: $!";
my ($portno, $ipaddr) = sockaddr_in($recvaddr);
my $dpong = $cipher->decrypt($pong);

my $pongCRC = crc32(substr($dpong,0,12));

my @pong = unpack('CSCCCCCCCCCL', $dpong);
print Dumper \@pong;
print "Calculated crc: $pongCRC\n";
print "    actual crc: $pong[11]\n";



