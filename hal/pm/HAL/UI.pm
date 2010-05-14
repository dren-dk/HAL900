package HAL::UI;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK NOT_FOUND REDIRECT);
use Apache2::SizeLimit;

use APR::Table ();
use Data::Dumper;
use CGI;
use Time::HiRes qw(gettimeofday);
#use HTTP::BrowserDetect;

use HAL;
use HAL::Pages;
use HAL::Layout;

sub loadDir {
    my $d = shift;
    l "Loading code from $d";

    opendir D, $d or die "Failed to open dir $d: $!";
    my @e = sort grep {!/^\./} readdir D;
    closedir D;

    for my $e (@e) {
	my $fn = "$d/$e";
	if (-d $fn) {
	    loadDir($fn);

	} elsif (-f $fn and $fn =~ /\.pm$/) {
	    open F, "<$fn" or die "Failed to read $fn: $!";
	    local $/ = undef;
	    my $perl = <F>;
	    close F;
	    eval($perl) or die "Failed to load $fn: $@";	    
	}
    }
}

sub bootStrap() {
    loadDir(HALRoot().'/pm/HAL/Page');
}


sub dispatchRequest($) {
    my ($r) = @_;
    
    Apache2::SizeLimit::setmax(300000, $r);
    
    my $q = CGI->new($r);
    
    # Parse the uri to figure out what function to call:
    my @uri = split '/', $r->uri;
    die unless '' eq shift @uri;
    
    my $p = {};
    for my $n ($q->param) {
	$p->{$n} = $q->param($n);
    }
    for my $i (0..@uri-1) {
	$p->{"p$i"} = $uri[$i];
    }
    
    my $handler = shift @uri || ''; 
    $p->{path} = \@uri;

    my $t0 = gettimeofday;
    my $res = callHandler($r,$q,$p);
    my $time = int(1000*(gettimeofday-$t0));
    
#       print STDERR Dumper $res;
    if (ref($res) eq 'HASH') {
	$res->{code} ||= Apache2::Const::OK;
	$res->{mime} ||= 'text/html';
	$res->{type} ||= 'menu';
	
	if ($res->{type} eq 'menu') {
	    $res->{mime} = 'text/html';
	    $res->{content} = htmlPageWithMenu($res->{opt}, $res->{items}, $res->{body});
	    
	} elsif ($res->{type} eq 'raw') {                       
	    if (!defined $res->{content}) {
		die 'Error: content was not set for raw output: '.Dumper $r->uri, $res, $p;
	    }
	    
	} elsif ($res->{goto}) {                        
	    print STDERR "Bouncing user to: $res->{goto}\n";
	    $r->headers_out->set(Location => $res->{goto});
	    $r->status(Apache2::Const::REDIRECT);  
	    return Apache2::Const::REDIRECT;
	    
	} else {
	    die "invalid output type: $res->{type}";
	}
	
	$r->content_type($res->{mime});
	print $res->{content};
	$r->status($res->{code}) if $res->{code};  
	return $res->{code};
	
    } elsif (ref $res) {
	die "Invalid return value from handler: ".Dumper $res;
	
    } else {
	return $res; # Raw Apache interaction.
    }       
}


# This is the handler that gets called by apache, it must never die!
sub handler {
    my $r = shift;
    
    eval {
	return dispatchRequest($r);
    };
    if ($@) {
	$r->content_type('text/plain');
	print "Something went wrong, please examine the error log for details\n\n";
	print $@ if testMode;
	
	print STDERR "Something went wrong:\n";
	print STDERR $@;
    }
    
    return Apache2::Const::OK;
}

42;
