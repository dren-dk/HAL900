#!/usr/bin/perl
use strict;
use warnings;

open R, "</dev/urandom" or die "Fail: $!";
for my $i (0..31) {
    my $data;
    read(R, $data, 1) or die "Couldn't read from /dev/urandom";
    my $byte = unpack('C',$data);
    print sprintf("0x%0x, ", $byte);
}
close R;

print "\n";
