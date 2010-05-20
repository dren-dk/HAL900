package HAL::UI;
use strict;
use warnings;
use utf8;

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::Const -compile => qw(OK NOT_FOUND REDIRECT);
use Apache2::SizeLimit;
use Apache2::Connection;

use APR::Table ();
use Data::Dumper;
use CGI;
use CGI::Cookie;
use Time::HiRes qw(gettimeofday);
#use HTTP::BrowserDetect;
use Encode;

use HAL;
use HAL::Pages;
use HAL::Layout;
use HAL::Session;

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

sub bootStrap($) {
    my ($p) = @_;

    setTestMode($p->{test});
    setHALRoot($p->{root});
    setEmailSalt($p->{salt}||'secret');

    loadDir(HALRoot().'/pm/HAL/Page');
}


sub dispatchRequest($) {
    my ($r) = @_;

    setCurrentIP($r->connection->remote_ip());

    Apache2::SizeLimit::setmax(300000, $r);
    
    my $q = CGI->new($r);
    
    # Parse the uri to figure out what function to call:
    my @uri = split '/', $r->uri;
    die unless '' eq shift @uri;
    
    my $p = {};
    for my $n ($q->param) {
	$p->{$n} = Encode::decode_utf8($q->param($n));
    }
    for my $i (0..@uri-1) {
	$p->{"p$i"} = $uri[$i];
    }
    
    my $handler = shift @uri || ''; 
    $p->{path} = \@uri;


    # Cookie setting.
    my $internal = undef;

    if (my $cookie_str = $r->headers_in->get('Cookie')) {
	my %cookies = parse CGI::Cookie($cookie_str);
	loadSession($cookies{SID}->value) if $cookies{SID};
    }

    if (getSessionID) {
	if (isLoggedIn) {
	    setCurrentUser("id:".getSession->{member_id});
	}

    } else {
	newSession();		
	$r->headers_out->set('P3P', 'CP="CAO ADM OUR IND PHY ONL PUR NAV DEM CNT STA"');
	$r->headers_out->set('MSIE', 'Sucks the goats balls!');    
	$r->headers_out->set("Set-Cookie", new CGI::Cookie(-name=>'SID', -value=>getSessionID, -path=>'/'));

	if ($r->uri ne '/hal/nocookie') {
	    l "Redirecting away from uri to get cookie: ".$r->unparsed_uri;

	    getSession()->{wanted} = $r->unparsed_uri;
	    $internal = outputGoto('/hal/nocookie');
	}
    }

    if (!$internal and !canAccess($r->uri)) {
	getSession()->{wanted} = $r->unparsed_uri;
	$internal = outputGoto('/hal/login');
    }

    # Call the actual handler.
    my $t0 = gettimeofday;
    my $res = $internal || callHandler($r,$q,$p);
    my $time = int(1000*(gettimeofday-$t0));

    if (ref($res) eq 'HASH') {
	$res->{code} ||= Apache2::Const::OK;
	$res->{mime} ||= 'text/html';
	$res->{type} ||= 'menu';
	
	if ($res->{type} eq 'menu') {
	    $res->{mime} = 'text/html; charset=UTF-8';
	    $res->{content} = htmlPageWithMenu($res->{opt}, $res->{items}, $res->{body});
	    
	} elsif ($res->{type} eq 'raw') {                       
	    if (!defined $res->{content}) {
		die 'Error: content was not set for raw output: '.Dumper $r->uri, $res, $p;
	    }
	    
	} elsif ($res->{goto}) {                        
#	    l "Bouncing user to: $res->{goto}\n";
	    $r->headers_out->set(Location => $res->{goto});
	    $r->status(Apache2::Const::REDIRECT);  
	    return Apache2::Const::REDIRECT;
	    
	} else {
	    die "invalid output type: $res->{type}";
	}
	
	$r->content_type($res->{mime});
	binmode(STDOUT, ':utf8' );
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
	dbRollback;
	$r->content_type('text/plain');
	print "Something went wrong, please examine the error log for details\n\n";
	print $@ if testMode;
	
	print STDERR "Something went wrong:\n";
	print STDERR $@;
    } else {
	storeSession if getSessionID; 
	dbCommit;
    }
    
    return Apache2::Const::OK;
}

42;
