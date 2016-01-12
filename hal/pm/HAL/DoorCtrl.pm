#-*-perl-*-
package HAL::DoorCtrl;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(pingDoor getDoorState addDoorKey deleteDoorKey addDoorHash deleteDoorHash decryptById keyHash);

use strict;
use warnings;
use Time::HiRes qw(gettimeofday);
use IO::Socket;
use Crypt::Rijndael;
use Data::Dumper;

sub getKey($) {
	my ($node) = @_;

	my $keystore = "$ENV{HOME}/.hal/keys";
	my $kf = "$keystore/node-$node.key";

	die "The keyfile for $node does not exist: $kf" unless -f $kf;
	 
	open K, "<$kf" or die "Failed to read $kf: $!";
	my $aesKey = join '', <K>;
	close K;
	
	$aesKey =~ s/\n/ /g;
	my @key = map {oct $_} split /\s*,\s*/, $aesKey;
	
	die "Invalid key size for node $node" unless @key == 32;
	
	return @key;	
}

my %REQUEST_TYPES = (
    'p' => 'Ping',
    'g' => 'Get state',
    'a' => 'Add key',
    'd' => 'Delete key',
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

sub decrypt {
    my ($cipher, $eres) = @_;

    my $res = $cipher->decrypt($eres);
    my $resCRC = crc32(substr($res,0,12));    
    my @res = unpack('CSCCCCCCCCCL', $res);
    
    if ($res[11] != $resCRC) {
		print STDERR "Failed to parse package due to bad CRC: $res[11] != $resCRC\n";
		return 'CRC failed';
    }
    
    push @res, substr($res, 3,9); # The raw payload.
    
    return @res;
}

sub decryptById {
    my ($id, $eres) = @_;

    my $key = join('', map {chr($_)} getKey($id));
    my $cipher = Crypt::Rijndael->new($key , Crypt::Rijndael::MODE_ECB() );

    return decrypt($cipher, $eres);
}

sub reqUDP {
    my ($addr, $rsize, $ereq) = @_;

    my $s = IO::Socket::INET->new(Proto => 'udp', PeerPort=>4747, PeerAddr=>$addr) 
	or return ("socket: $@", undef);     # yes, it uses $@ here
    
    $s->send($ereq) == length($ereq)
	or return ("cannot send: $!", undef);
    
    my $eres;
    my $ok = eval {
		local $SIG{ALRM} = sub { die "alarm time out" };
		alarm 10;
		$s->recv($eres, $rsize)  or die "recv: $!";
		alarm 0;
		1;  # return value from eval on normalcy
    };

    unless ($ok) {
		print STDERR "Answer to request never arrived; timeout.\n";
		return ('Timeout', undef);	
    };

    return ('Ok', $eres);
}

sub reqTCP {
    my ($tunnel, $addr, $rsize, $ereq) = @_;

    die "Urgh";

}

my $tunnelServer;

sub req {
    my ($addr, $rsize, $ereq) = @_;
    
    if ($tunnelServer) {
	return reqTCP($tunnelServer, $addr, $rsize, $ereq);
    } else {
	return reqUDP($addr, $rsize, $ereq);
    }
}

sub pokeDoor($$$$) {
    my ($id, $type, $sequence, $payload) = @_;

    die "Invalid request type: $type" unless $REQUEST_TYPES{$type};
    die "Invalid sequence number: $sequence" unless $sequence >= 0 and $sequence <= 0xffff;
    die "Invalid payload size (must be 9 bytes)" unless length($payload) == 9;

    my $key = join('', map {chr($_)} getKey($id));
    
    my $req = pack('cs', ord($type), $sequence).$payload;
    $req .= pack('L', crc32($req));

    die "Request was not 16 bytes after assembly" unless length($req) == 16;
    
    my $cipher = Crypt::Rijndael->new($key , Crypt::Rijndael::MODE_ECB() );
    my $ereq = $cipher->encrypt($req);

    my ($status, $eres) = req("10.37.37.$id", 160, $ereq);

    if ($status ne 'Ok') {
	return $status;
    }

    return decrypt($cipher, $eres);

    my $res = $cipher->decrypt($eres);
    my $resCRC = crc32(substr($res,0,12));    
    my @res = unpack('CSCCCCCCCCCL', $res);

    if ($res[11] != $resCRC) {
		print STDERR "Answer to $type request failed CRC: $res[11] != $resCRC\n";
		return 'CRC failed';
    }

    push @res, substr($res, 3,9); # The raw payload.

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

sub decodeSensorState($) {
    my $byte = shift;

    return {
		closed0=> $byte & 0x01,
		locked0=> $byte & 0x02,
		closed1=> $byte & 0x04,
		locked1=> $byte & 0x08,
		closed2=> $byte & 0x10,
		locked2=> $byte & 0x20,
		closed3=> $byte & 0x40,
		locked3=> $byte & 0x80,	
	};       
}

sub getDoorState {
    my ($id) = @_;

    my @res = pokeDoor($id, 'g', 0, pack('CCCCCCCCC', 0,0,0, 0,0,0, 0,0,0));
    
    return undef unless @res == 13;
    
    my ($version, $sensorState) = unpack('CC', $res[12]);
    my $seq = $res[1];

    # Note: Only version 0 exists, when new versions are added the payload will grow.

    return {
		sequence=>$seq,
		sensors=>decodeSensorState($sensorState),
    };
}

sub keyHash($$) {
    my ($rfid, $pin) = @_;
    return $rfid ^ (0xffff0000 & ($pin << 16)) ^ (0x0000ffff & ($pin >> 16));
}

sub addDoorHash {
    my ($id, $seq, $hash) = @_;

    my @res = pokeDoor($id, 'a', $seq, pack('LCCCCC', $hash ,0,0, 0,0,0));

    return undef unless @res == 13;

    if ($res[2] == 1) {
		return 'ACK';

    } elsif ($res[2] == 2) {
		return 'NACK';

    } elsif ($res[2] == 3) {
		return 'NACK, no room';

    } else {
		return "Error ($res[2])";
    }    
}

sub addDoorKey {
    my ($id, $seq, $rfid, $pin) = @_;

    my $hash = keyHash($rfid, $pin);
    return addDoorHash($id, $seq, $hash);
}

sub deleteDoorHash {
    my ($id, $seq, $hash) = @_;

    my @res = pokeDoor($id, 'd', $seq, pack('LCCCCC', $hash ,0,0, 0,0,0));

    return undef unless @res == 13;

    if ($res[2] == 1) {
		return 'ACK';

    } elsif ($res[2] == 2) {
		return 'NACK';

    } else {
		return "Error ($res[2])";
    }
}

sub deleteDoorKey {
    my ($id, $seq, $rfid, $pin) = @_;
    
    my $hash = keyHash($rfid, $pin);
    return deleteDoorHash($id, $seq, $hash);
}

36;
