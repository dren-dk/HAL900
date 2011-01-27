#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Script $Bin);

die "Syntax: $Script <node>, reads nodes/<node>.config and generates nodeconfig.h" unless @ARGV == 1;
my ($node) = @ARGV;
my $cfg = "$Bin/nodes/$node.config";
die "Invalid node '$node' $cfg not found" unless -f $cfg;

my %cfg;
open CFG, "<$cfg" or die "Failed to read $cfg: $!";
while (my $line = <CFG>) {
	chomp $line;
	$line =~ s/^\s+//;
	$line =~ s/\s+$//;
	next if $line =~ /^#/;
	next unless $line;
	my ($k,$v) = $line =~ /^([^=]+?)\s*=\s*(.+)$/;
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

my $code;
my %used;

sub claim {
	my $user = shift;
	my @resource = @_;
	for my $r (@resource) {
		my $c = $used{$r};
		die "$user conflicts with $c on $r" if $c;
		$used{$r} = $user;		
	}	
}

for my $k (sort %cfg) {
	my $v = $cfg{$k};
	print "Checking $k=$v...";
	
	if ($k eq 'onboard.rfid') {
		if ($cfg{$k} eq '3') {
			claim("$k on $v", 'PD6', 'PB3', 'LED4');
			$code .= "#define USE_ONBOARD_RFID\n";						
			
		} elsif ($cfg{$k} eq 'no') {
			# Ok.
			
		} else {
			die "Invalid port must be either 3 or no";
		}
		
	} elsif ($k eq 'wiegand.rfid') {
		claim("$k on $v", $PORT{$v}{1}, $PORT{$v}{2}, $PORT{$v}{3}, $PORT{$v}{6}, $PORT{$v}{g}, $PORT{$v}{o});

		$code .= "#define USE_ONBOARD_RFID\n";						
		
		
	} elsif ($k eq 'wiegand.kbd') {
	} elsif ($k eq '') {
	} elsif ($k eq '') {
		
		
	}
	
#	onboard.rfid=con5

#rs485.id=1

# listen for commands on ethernet
#ethernet.ip=10.42.42.1
#ethernet.port=4747
	
}
 