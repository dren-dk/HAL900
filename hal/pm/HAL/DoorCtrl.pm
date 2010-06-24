#-*-perl-*-
package HAL::DoorCtrl;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(pingDoor);

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use IO::Socket;
use Crypt::Rijndael;
use Data::Dumper;

my %DOOR = (
    1=>{
	key=>[0x64, 0x4c, 0x3a, 0xd1, 0x96, 0x7,  0x8f, 0xbc,
	      0xe7, 0xc,  0x4e, 0x27, 0x20, 0xc2, 0x43, 0xb2,
	      0x5b, 0xa9, 0x38, 0x7f, 0x15, 0xaa, 0xc,  0x58,
	      0x83, 0x37, 0x0,  0x20, 0x56, 0x70, 0x8d, 0x59],
    },
);

my %REQUEST_TYPES = (
    'p' => 'Ping',
    'a' => 'Add key',
    'd' => 'Delete key',
    'c' => 'Check state',
);

sub crc32($) {
    my $buffer = shift;
    my @bytes = map {ord($_)} split //, $buffer;
    my $crc = 0xffffffff;

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

sub pokeDoor($$$$) {
    my ($id, $type, $sequence, $payload) = @_;

    die "Invalid request type: $type" unless $REQUEST_TYPES{$type};
    die "Invalid sequence number: $sequence" unless $sequence >= 0 and $sequence <= 0xffff;
    die "Invalid payload size (must be 9 bytes)" unless length($payload) == 9;

    my $keyList = $DOOR{$id}{key} or die "Invalid door id: $id";
    my $key = join('', map {chr($_)} @$keyList);
    
    my $req = pack('cs', ord($type), $sequence).$payload;
    $req .= pack('L', crc32($req));

    die "Request was not 16 bytes after assembly" unless length($req) == 16;
    
    my $cipher = Crypt::Rijndael->new($key , Crypt::Rijndael::MODE_ECB() );
    my $ereq = $cipher->encrypt($req);

    my $s = IO::Socket::INET->new(Proto => 'udp', PeerPort=>4747,
				  PeerAddr=>"10.0.0.$id") 
	or die "socket: $@";     # yes, it uses $@ here
    
    $s->send($ereq) == length($ereq)
	or die "cannot send: $!";
    
    my $eres;
    my $ok = eval {
	local $SIG{ALRM} = sub { die "alarm time out" };
	alarm 10;
	$s->recv($eres, 160)  or die "recv: $!";
	alarm 0;
	1;  # return value from eval on normalcy
    };

    unless ($ok) {
	print STDERR "Answer to $type request never arrived; timeout.\n";
	return 'Timeout';	
    };

    my $res = $cipher->decrypt($eres);
    my $resCRC = crc32(substr($res,0,12));    
    my @res = unpack('CSCCCCCCCCCL', $res);

    if ($res[11] != $resCRC) {
	print STDERR "Answer to $type request failed CRC: $res[11] != $resCRC\n";
	return 'CRC failed';
    }

    return @res;    
}

sub pingDoor {
    my ($id, $seq) = @_;
    $seq ||= 1;

    my $t0 = gettimeofday;
    my @res = pokeDoor($id, 'p', $seq, '123456789');
    my $t1 = gettimeofday;

    if (@res > 1) {
	return int(1000*($t1-$t0));
    } else {
	return -1;
    }
}
