#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin $Script);
use WWW::Mechanize;
use Storable qw(nstore retrieve);

die "Syntax: $Script <kicad cmp file> <output csv>" unless @ARGV == 2;
my ($input, $output) = @ARGV;

my %PACKAGES = (
    'C0805' => '0805',
    'C1210' => '1210',
    'R0805' => '0805',
    'SOT23-BEC' => 'SOT-23',

    'SM0805' => '0805',
    'R1'=>'axial',
);

open CMP, "<$input" or die "Failed to read input file $input: $!";
my $cmpStr = join '', <CMP>;
close CMP;

#BeginCmp
#TimeStamp = /4CFAB038;
#Reference = C1;
#ValeurCmp = 16pF;
#IdModule  = SM0805;
#EndCmp

my %parts;
for my $cmp ($cmpStr =~ /BeginCmp(.+?)EndCmp/sg) {
    my %c;
    for my $l (split /\n/, $cmp) {
	if ($l =~ /(\S+)\s*=\s*([^;]+);/) {
	    my ($k, $v) = ($1,$2);
	    $c{$k} = $v;
	}
    }
    
    my $name    = $c{Reference};
    my $value   = $c{ValeurCmp};
    my $package = $c{IdModule};

    $name =~ s/\s+$//;
    $value =~ s/\s+$//;
    $value =~ s/_//g;
    $package =~ s/\s+$//;

    if (exists $PACKAGES{$package}) {
	$package = $PACKAGES{$package};
    }
  
    my $type = $value ne '' ? "$value $package" : $package;    
    push @{$parts{$type}}, $name;
}

my %elfa;
if (open EE, "<$Bin/elfa.parts") {
  while (my $e = <EE>) {
    chomp $e;
    my ($type, $elfa) = split("\t", $e);
    if (my ($v,$p) = $type =~ /(.+)\s(\S+)$/) {
	$v =~ s/[\s_]//g;
	$elfa{"$v $p"} = $elfa;    
    } else {
	$elfa{$type} = $elfa;
    }
  }
  close EE;
}

my $skipKnown = 1;
for my $type (sort keys %parts) {

  next if $elfa{$type} and $skipKnown;

  my @names = @{$parts{$type}};
  my $count = @names;
  my $etype = $type;
  $etype =~ s/\s/+/g;
  print "$type count=$count ",
    join(' ', @names), 
    "\n", 
    "https://www.elfa.se/elfa3~dk_en/elfa/init.do?shop=ELFA_DK-EN&query=$etype",
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
    if ($ep =~ /^\d{2}-\d{3}-\d{2}$/ or $ep eq 'alt') {
      $elfa{$type} = $ep;
      open EE, ">$Bin/elfa.parts" or die "urgh: $!";
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
    if ($ep eq 'S') {
      print "Skipped, skipping all with defaults\n";
      $skipKnown = 1;
      last;
    }
    if ($elfa{$type} and ($ep eq '')) {
      print "Keeping default\n";
      last;
    }
        
    print "heh? Try again\n";
  }
}

my $priceStore = "$Bin/elfa-prices.stored";
my $priceCache = -f $priceStore ? retrieve($priceStore) : {};
open OUT, ">$output" or die "Failed to write $output: $!";
for my $type (sort keys %parts) {
  my @names = @{$parts{$type}};
  my $count = @names;
  my $elfa = $elfa{$type} or die "Urgh $type";

  if ($elfa eq 'alt') {
      print OUT join("\t", $type, join(' ', @names), $elfa, $count, 0, 0,
		     "Not ELFA"), "\n";
      next;
  }
  
  my $price = $priceCache->{$elfa};
  
  if (!$price) {
    print "Looking up price for $elfa\n";
    my $m = WWW::Mechanize->new();
    $m->get("https://www.elfa.se/elfa3~dk_en/elfa/init.do?item=$elfa");
    my $html = $m->content();

    my @prices;
    my ($priceList) = $html =~ m!<td[^>]*id="item-pricelist">\s*<table>\s*(.+?)\s*</table>\s*</td>!s;
    if ($priceList) {
      @prices = $priceList =~ m!<td class="price">([^>]+)</td>!g;
      die "Failed to find prices in $priceList" unless @prices;
    } else  {
      @prices = $html =~ m!<td[^>]*id="item-pricelist">\s*<span>\s*(.+?)\s*</span>\s*</td>!s
	  or die "Failed to find price for $elfa";      
    }
    my $normalPrice = $prices[0];
    my $osaaPrice = $prices[@prices-1];
    
    $price = $priceCache->{$elfa} = [ $normalPrice, $osaaPrice ];
    
    nstore($priceCache, $priceStore);
    sleep(1);
  }   
  
  print OUT join("\t", $type, join(' ', @names), $elfa, $count, $price->[0], $price->[1],
    "https://www.elfa.se/elfa3~dk_en/elfa/init.do?item=$elfa"), "\n";
}
close OUT;
