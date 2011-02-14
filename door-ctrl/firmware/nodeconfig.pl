#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Script $Bin);
use Data::Dumper;
use File::Path qw(make_path);

die "Syntax: $Script <node>, reads nodes/<node>.config and generates nodeconfig.h" unless @ARGV == 1;
my ($node) = @ARGV;
my $cfg = "$Bin/nodes/$node.config";
die "Invalid node '$node' $cfg not found" unless -f $cfg;

my $keystore = "$ENV{HOME}/.hal/keys";
make_path $keystore unless -d $keystore;
my $kf = "$keystore/node-$node.key";

my $aesKey;

if (-f $kf) { 
	open K, "<$kf" or die "Failed to read $kf: $!";
	$aesKey = join '', <K>;
	close K;
	
} else {
	
	my $k = '';
	my $sep = '';
	open R, "</dev/urandom" or die "Fail: $!";
	for my $i (0..31) {
	    my $data;
	    read(R, $data, 1) or die "Couldn't read from /dev/urandom";
	    my $byte = unpack('C',$data);
	    $k .= $sep;
	    $k .= " \n    " if $sep and $i % 8 == 0;
	    $sep = ', ';
	    $k .= sprintf("0x%0x", $byte);
	}
	close R;
	$aesKey = $k;
	
	open K, ">$kf" or die "Failed to write $kf: $!";
	print K $aesKey;
	close K;
}

$aesKey =~ s/\n/\\\n/g; 

my %cfg;
open CFG, "<$cfg" or die "Failed to read $cfg: $!";
while (my $line = <CFG>) {
	chomp $line;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	next if $line =~ /^#/;
	next unless $line;
	my ($k,$v) = $line =~ /^([^=]+?)\s*=\s*(.+)$/;
	die "Failed to parse $line" unless defined $k and defined $v;
	
	$cfg{$k} = $v;
}
close CFG;

my %PORT = (
	1=>{
		1=>'PA0',
		2=>'PA1',
		3=>'PA2',
		6=>'PA3',
		g=>'LED0',
		o=>'LED1',			
	},
	2=>{
		1=>'PA4',
		2=>'PA5',
		3=>'PA6',
		6=>'PA7',
		g=>'LED2',
		o=>'LED3',			
	},
	3=>{
		1=>'PB3',
		2=>'PD6',
		3=>'PD5',
		6=>'PD4',
		g=>'LED4',
		o=>'LED5',			
	},
);

my %features;
my $code;
my %used;
my $hasWiegand = 0;

sub claim {
	my $user = shift;
	my @resource = @_;
	for my $r (@resource) {
		my $c = $used{$r};
		die "$user conflicts with $c on $r" if $c;
		$used{$r} = $user;
		push @{$features{$user}}, $r; 		
	}	
}

for my $k (sort keys %cfg) {
	my $v = $cfg{$k};
	print "Checking $k=$v...";
	
	if ($k eq 'onboard.rfid') {
		if ($cfg{$k} eq 'yes') {
			claim("Onboard RFID on port 3", 'PD6', 'PB3', 'LED4');
			$code .= "#define ONBOARD_RFID\n";						
			
		} elsif ($cfg{$k} eq 'no') {
			# Ok.
			
		} else {
			die "Invalid port must be either yes or no";
		}
		
	} elsif ($k eq 'wiegand.rfid') {
		claim("Wiegand RFID on port 1", $PORT{1}{1}, $PORT{1}{2}, $PORT{1}{3}, $PORT{1}{6}, $PORT{1}{g}, $PORT{1}{o});
		die "Invalid wiegand rfid port" unless $v =~ /^(yes|no)$/;

		if ($v ne 'no') {
			$code .= "#define WIEGAND_RFID\n";
			$hasWiegand = 1;
		}	
		
	} elsif ($k eq 'wiegand.kbd') {
		claim("Wiegand Keypad on port 2", $PORT{2}{1}, $PORT{2}{2}, $PORT{2}{3}, $PORT{2}{6}, $PORT{2}{g}, $PORT{2}{o});
		die "Invalid wiegand keyboard port" unless $v =~ /^(yes|no)$/;
		
		if ($v ne 'no') {
			$code .= "#define WIEGAND_KBD\n";
			$hasWiegand = 1;
		}	
		
	} elsif ($k eq 'rs485.id') {
		die "Invalid rs485 id" unless $v =~ /^\d+$/ and $v >= 0 and $v <= 255;
		$code .= "#define RS485_ID $v\n";
		
		if ($v) {
			claim("RS485 node id $k", 'PD0', 'PD1', 'PD7', 'PC2');
		} else {
			claim("RS485 master", 'PD0', 'PD1', 'PD7', 'PC2');
		}
		
	} elsif ($k eq 'ethernet.ip') {
		die "Invalid ip" unless $v =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;
		my @ip = split(/\./, $v);
		for my $i (@ip) {
			die "Your IP is full of fail" unless $i >= 0 and $i <= 255;
		}
		my $ip = join ',', @ip;

		my $port = $cfg{'ethernet.port'} || 4747;		
		die "Invalid port" unless $port =~ /^\d+$/ and $port >= 1 and $port <= 65535;

		my $mac = join(',', 0x05, 0xAA, @ip); # We use 05AA as the prefix, because we're OSAA...

		$code .= "#define USE_ETHERNET\n";
		$code .= "#define ETHERNET_IP {$ip}\n";
		$code .= "#define ETHERNET_MAC {$mac}\n";
		$code .= "#define UDP_PORT $port\n";
		claim("ENC28J60", 'PB6', 'PB7', 'PB5', 'PB4');
				
	} elsif ($k eq 'ethernet.port') {
		# Ignore.

	} else {
		die "Invalid key in $cfg: $k";
	}
	print "\n";
}

$code .= "#define HAS_WIEGAND\n" if $hasWiegand;

$code .= "\n/* Port allocation\n\n";
for my $f (sort keys %features) {
	$code .= " $f:\n";			
	for my $r (sort @{$features{$f}}) {
		$code .= "   $r\n";		
	}	
	$code .= "\n";			
}

$code .= "*/\n";


open H, ">$Bin/nodeconfig.h" or die "Failed to write $Bin/nodeconfig.h: $!";
print H qq'#ifndef NODECONFIG_H
#define NODECONFIG_H

/*
	Node configuration for node: $node

	Notice: This board configuration file was written by the $Script script, which means that
	all changes to this file will be overwritten by the build process, if you wish to change
	any parameters for this node, edit $cfg and re-run $Script $node 
*/

$code

// Key read from $kf:
#define NODE_AES_KEY $aesKey

#endif
';
close H;

print "Generated $Bin/nodeconfig.h for node $node\n";

exit 0;
