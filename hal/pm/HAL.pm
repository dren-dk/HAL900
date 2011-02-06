#-*-perl-*-
package HAL;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(testMode HALRoot emailSalt getDBUrl configureHAL);

use strict;
use warnings;

my $config;
sub testMode() {
    return $config->{test};
}

sub HALRoot() {
    return $config->{root};
}
sub emailSalt() {
    return $config->{salt};
}

sub getDBUrl() {
    return $config->{db};
}

sub configureHAL {
    my $host = shift;
    $host ||= `hostname`;
    chomp $host;    

    die "HOST environment variable not defined, cannot self-configure." unless $host;

    my %CONFIG = (
	panther=>{
	    root=>"/home/ff/projects/osaa/hal",
	    test=>1,
	    salt=>'345klj56kl',
	    db=>'dbi:Pg:dbname=hal;port=5433',
	},
	hal=>{
	    root=>"/home/hal/hal",
	    test=>0,
	    salt=>'345klj56kl',
	    db=>'dbi:Pg:dbname=hal;port=5432'	    
	},
	lisbeth=>{
	    root=>"/home/jacob/Desktop/HACK/hal",
	    test=>1,
	    salt=>'345klj56kl',
	    db=>'dbi:Pg:dbname=hal;port=5432',
	},

    );
    
    $config = $CONFIG{$host} || die "HOST=$host is not found in \%CONFIG, cannot self-configure, fix pm/HAL.pm";
}

BEGIN {
    configureHAL();
}


42;
