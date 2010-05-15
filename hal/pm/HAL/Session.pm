#-*-perl-*-
package HAL::Session;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(loadSession storeSession newSession getSession getSessionID);

use strict;
use warnings;
use Digest::SHA qw(sha1_hex);
use Time::HiRes qw(gettimeofday);
use HAL::Pages;

sub parseProperties($) {
    my $data = shift;
    
    my %props;
    $data =~ s/\\\n//gsm; # Support \ line continuations
    $data =~ s/\\:/:/gsm; # Support \: escapes
    $data =~ s/\\\\/\\/gsm; # Support \\ escapes
    for my $l (split "\n", $data) {
	if ($l =~ /^([^=\s\#]+)[\t ]*=[\t ]*([^\n]*?)[\t ]*$/) {
	    my ($k, $v) = ($1, $2);
	    $props{$k} = $v;
	}
    }
    return %props;              
}

my %session;
my $sessionID;
sub loadSession($) {
    my ($id) = shift;

    my $sth = db->sql("select datablob from websession where id=?", $id);
    my ($blob) = $sth->fetchrow_array();
    $sth->finish;

    if (defined $blob) {
	%session = parseProperties($blob);
	$sessionID = $id;
    } else {
	%session = ();
	$sessionID = undef;
    }
}

sub getSession() {
    return \%session;
}

sub getSessionID() {
    return $sessionID;
}

sub storeSession() {    
    die "No session to store" unless $sessionID;

    my $blob = '';
    for my $k (sort keys %session) {
	$blob .= "$k=$session{$k}\n";
    }

    db->sql("update websession set datablob=? where id=?", $blob, $sessionID);
}

my $sessionCount = $$;
sub newSession() {
    $sessionCount++;
    $sessionID = substr(sha1_hex("$$.".gettimeofday.".$sessionCount"), 20);
    %session = ();
    db->sql("insert into websession (id, datablob) values (?, '')", $sessionID);
}
