#-*-perl-*-
package HAL;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(setTestMode testMode HALRoot setHALRoot emailSalt setEmailSalt setDBUrl getDBUrl);

use strict;
use warnings;

my $testMode = 0;
sub setTestMode($) {
    $testMode = shift;
}
sub testMode() {
    return $testMode;
}

my $HALRoot;
sub setHALRoot($) {
    $HALRoot = shift;
    die "This is not a HALRoot: $HALRoot" unless -f "$HALRoot/pm/HAL.pm";
    return $HALRoot;
}

sub HALRoot() {
    return $HALRoot ? $HALRoot : setHALRoot($FindBin::Bin);
}

my $emailSalt = "secret";
sub emailSalt() {
    return $emailSalt;
}

sub setEmailSalt($) {
    $emailSalt=shift;
}

my $dbUrl;
sub setDBUrl($) {
    $dbUrl = shift;
}

sub getDBUrl() {
    return $dbUrl;
}

42;
