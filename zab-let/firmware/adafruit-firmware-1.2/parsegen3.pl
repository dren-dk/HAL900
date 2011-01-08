#!/usr/bin/perl
use strict;
use warnings;

sub round {
    my($number) = shift;
    return int($number + .5);
}

my @files;
for my $arg (@ARGV) {
    #print "$arg\n"; 
    if (opendir(DIR, $arg)) {
	push @files, map { "$arg/$_" } grep { /\.dat$/} readdir(DIR);
	closedir(DIR);

	for my $f (@files) {
	    
	}
	next;
    } else {
	push @files, $arg;
    }
}
my @allbitstrings;
my @timecodetables;
for my $file (@files) {
#    print "opening datafile $file\n";
    open(INPUT, "<$file") or die $!;
#    my $outname = "$file.out";
#    open(OUTPUT, ">", $outname) or die $!;
    
    $file =~ /([a-z0-9]+).dat/ or die "$file is misnamed";
    my $codename = $1;
    
    my $avgperiod = 0;
    my $freq = 0;
    my @pulses;
    my $currentpulselen = 0;
    while (my $line = <INPUT>) {
	$line =~ /[0-9]+:\s+1\s+([0-9]+)\s+0\s+([0-9]+)/ or next;
	my $timeon = $1;
	my $timeoff = $2;
	
	#print "$timeon   $timeoff\n";
	
	# for now, lets assume that the first line will tell us the freq
	if ($freq == 0) {
	    $avgperiod = $timeon + $timeoff;
	    $freq = round(1000000000/$avgperiod); #avgperiod is in ns
	    #print "\nDetected $freq carrier frequency\n"
	    # MEME: check that 90% of the lines have the same timing?
	}
	
	# Note that the timing can be off by 100 nanoseconds and we'll let it slide
	if ((($timeon + $timeoff - 100) <= $avgperiod) &&
	    (($timeon + $timeoff + 100) >= $avgperiod)) {
	    # This line is a carrier (high)
	    $currentpulselen += $timeon + $timeoff;
	} else {
	    # ok end of a pulse, it seems
	    $currentpulselen += $timeon;
	    $currentpulselen = round($currentpulselen/10000)/10.0;
	    push(@pulses, $currentpulselen);
	    #print "pulse high $currentpulselen ms\n";
	    $currentpulselen = 0;  # reset
	    #print $line;
	    $timeoff = round($timeoff/10000)/10.0;
	    push(@pulses, $timeoff);
	    #print "pulse low $timeoff ms\n";
	}
    }
    
    #####################################################################
    # To debug, we can print out the pairs
#    while (my ($a,$b) = each @pulses) {
#	print "$a , $b\n";
#    }
    
    #####################################################################
    # Pair up each On and Off timing code into an array

    my @pairs;
    for (my $i = 0; $i < @pulses ; $i+= 2) {	
	push @pairs, [@pulses[$i,$i+1]];
    }

    my %seen;
    my @uniquepairs = grep {
	!$seen{"$_->[0],$_->[1]"}++;
    } @pairs;


    #####################################################################
    # Now sort them, so we can detect duplicates eaiser!

    @uniquepairs = sort { $a->[0] <=> $b->[0] || $a->[1] <=> $b->[1] } @uniquepairs;


    #print "Unique pulse pairs: \n";
    #for ($i = 0; $i < @uniquepairs ; $i++) {
    #  print "$uniquepairs[$i][0] $uniquepairs[$i][1]\n";
    #}
    #  print "\nTiming table bytes used: ".(@uniquepairs * 4)."\n";

    #####################################################################
    # To save space we detect duplicate timing tables so we can reuse them

    my $duplicateTimeTable = 0;
    my $timetablename = $codename;    
    my $timecodename;
    for my $timetable (@timecodetables) {
	$timetable = [ @$timetable ];
	$timecodename = $timetable->[0];

	#print "length = ". ((scalar @$timetable) -1). " $timecodename \n";
	if (((scalar @$timetable) - 1) != @uniquepairs) {
	    # not the same length so def. not the same
	    next;
	}
	# same length, lets compare!
	for (my $timei=1; $timei < (scalar @$timetable); $timei++) {
	    #print "$timetable->[$timei][0] , $timetable->[$timei][1]\t$uniquepairs[$timei][0], $uniquepairs[$timei][1]\n";
	    if ( ($timetable->[$timei][0] == $uniquepairs[$timei-1][0]) &&
		 ($timetable->[$timei][1] == $uniquepairs[$timei-1][1]) ) {
		$duplicateTimeTable = 1;
	    } else {
		#print "nomatch\n";
		$duplicateTimeTable = 0;
		last;
	    }
	}
	if ($duplicateTimeTable) {
	    $timetablename = $timecodename;
	    last;
	}
    }

    # add to our collection of timecode tables
    push (@timecodetables, [$codename, @uniquepairs]);

    ###################################################################
    # Output the  the timing table
    print "\n";
    if ($duplicateTimeTable) {
	print "\n/* Duplicate timing table, same as $timecodename !\n";
    }
    print "const uint16_t code_".$codename."Times[] PROGMEM = {\n";
    for my $pair (@uniquepairs) {
	print "\t".($pair->[0]*10).", ".($pair->[1]*10).",\n";
    }
    print "};\n";

    if ($duplicateTimeTable) {
	print "*/\n";
    }

    ###################################################################
    # Calculate how many bits we need to index into the timing table
    
    my $compression;
    if (@uniquepairs <= 4) {
	$compression = 2;
    } elsif (@uniquepairs <= 8) {
	$compression = 3;
    } elsif (@uniquepairs <= 16) {
	$compression = 4;
    } elsif (@uniquepairs <= 32) {
	$compression = 5;
    } elsif (@uniquepairs <= 64) {
	$compression = 6;
    } elsif (@uniquepairs <= 128) {
	$compression = 7;
    } elsif (@uniquepairs <= 256) {
	$compression = 8;
    } else {
	exit("too many unique pairs!");
    }

    if (@pairs > 255) {
	exit("too many pairs!");
    }

    ###################################################################
    # Output the IR code

    print "const struct IrCode code_${codename}Code PROGMEM = {\n";
    print "\tfreq_to_timerval($freq),\n";
    print "\t".@pairs.",\t\t// # of pairs\n";
    print "\t$compression,\t\t// # of bits per index\n";
    print "\tcode_${timetablename}Times,  \n\t{\n";
    my $bitstring = "";
    for (my $i=0; $i<@pairs; $i++) {
	
	for (my $j=0; $j<@uniquepairs; $j++) {
	    if (($uniquepairs[$j][0] == $pairs[$i][0]) &&
		($uniquepairs[$j][1] == $pairs[$i][1])) {
	
		# we stuff the bits into a really long string of 0's and 1's
		$bitstring .= sprintf "%0${compression}B", $j;
		#last;
	    }
	}
    }
    # We'll break up the bit string into bytes, make sure its padded nicely
    while (length($bitstring) % 8) {
	$bitstring .= "0";
    }



    #print "$bitstring (".length($bitstring).")\n";

    # divvy it up into 8's and print out hex codes
    for (my $i =0; $i < length($bitstring); $i += 8) {
	my $byte = 
	    128 * substr($bitstring, $i, 1) +
	    64 * substr($bitstring, $i+1, 1) +
	    32 * substr($bitstring, $i+2, 1) +
	    16 * substr($bitstring, $i+3, 1) +
	    8 * substr($bitstring, $i+4, 1) +
	    4 * substr($bitstring, $i+5, 1) +
	    2 * substr($bitstring, $i+6, 1) +
	    1 * substr($bitstring, $i+7, 1);
	printf "\t\t0x%02X,\n", $byte;
    }
    print "\t}\n};";

    for my $bits (@allbitstrings) {
	if ($bits eq $bitstring) {
	    print "// Duplicate IR Code???\n";
	}
    }
    push (@allbitstrings, $bitstring);
    
}
