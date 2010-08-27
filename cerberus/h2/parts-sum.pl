#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin $Script);

die "Syntax: $Script <eagle bom file>" unless @ARGV == 1;
my ($input) = @ARGV;

my %PACKAGES = (
  'C0805' => '0805',
  'C1210' => '1210',
  'R0805' => '0805',
  'SOT23-BEC' => 'SOT-23',
);

my %parts;
open EAGLE, "<$input" or die "Failed to read input file $input: $!";
while (my $line = <EAGLE>) {
  chomp $line;
  next unless $line =~ /\s\d$/;
  
  my $name   = substr($line, 0, 9);
  my $value  = substr($line, 9, 14);
  my $package= substr($line, 47, 12); 

  $name =~ s/\s+$//;
  $value =~ s/\s+$//;
  $package =~ s/\s+$//;

  if ($PACKAGES{$package}) {
    $package = $PACKAGES{$package};
  }

  push @{$parts{"$value $package"}}, $name;
}
close EAGLE;

my %elfa;
if (open EE, "<$Bin/eagle2elfa.parts") {
  while (my $e = <EE>) {
    chomp $e;
    my ($eagle, $elfa) = split("\t", $e);
    $elfa{$eagle} = $elfa;    
  }
  close EE;
}

for my $type (sort keys %parts) {
  my @names = @{$parts{$type}};
  my $count = @names;
  print "$type count=$count ",
    join(' ', @names), 
    "\n", 
    "https://www.elfa.se/elfa3~dk_en/elfa/init.do?shop=ELFA_DK-EN&query=$type",
    "\n";
    
  my $ep;
  while (1) {
    if ($elfa{$type}) {
      print "ELFA part number (default: $elfa{$type}): ";
    
    } else {
      print "ELFA part number: ";
    }
    $ep = <STDIN>;
    $ep =~ s/^\s+//;
    $ep =~ s/\s+$//;
    if ($ep =~ /^\d{2}-\d{3}-\d{2}$/) {
      $elfa{$type} = $ep;
      open EE, ">$Bin/eagle2elfa.parts" or die "urgh: $!";
      for my $e (sort keys %elfa) {
	print EE "$e\t$elfa{$e}\n";
      }
      close EE;
      
      print "Ok, saved\n";
      last;
    } 
    if ($ep eq 's') {
      print "Skipped\n";
      last;
    }
    if ($elfa{$type} and $ep eq '') {
      print "Keeping default\n";
      last;
    }
        
    print "heh? Try again\n";
  }
}

for my $type (sort keys %parts) {
  my @names = @{$parts{$type}};
  my $count = @names;
  print join("\t", $type, join(' ', @names), $count, 
    "https://www.elfa.se/elfa3~dk_en/elfa/init.do?shop=ELFA_DK-EN&query=$type"), "\n";
}

__DATA__
for my $type (sort keys %parts) {
  my @names = @{$parts{$type}};
  my $count = @names;
  print join("\t", $type, join(' ', @names), $count, 
    "https://www.elfa.se/elfa3~dk_en/elfa/init.do?shop=ELFA_DK-EN&query=$type"), "\n";
}