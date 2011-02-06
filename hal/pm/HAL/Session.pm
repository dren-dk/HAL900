#-*-perl-*-
package HAL::Session;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(loadSession storeSession newSession getSession getSessionID ensureAdmin ensureLogin ensureDoor canAccess loginSession logoutSession isLoggedIn isAdmin clearSession);

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

my %secure;
sub ensureLogin($) {
    my ($rx) = @_;
    $secure{qr/$rx/} = 'login';
}

sub ensureAdmin($) {
    my ($rx) = @_;
    $secure{qr/$rx/} = 'admin';    
}

sub ensureDoor($) {
    my ($rx) = @_;
    $secure{qr/$rx/} = 'door';    
}

sub canAccess($) {
    my ($uri) = @_;

    for my $s (keys %secure) {
	if ($uri =~ m/$s/) {

	    return 0 unless $session{member_id};
	    return 2 if index($session{access}||'', $secure{$s}) >= 0;
	    return 0;
	}
    }
    return 1;
}

sub isLoggedIn() {
    return 0 unless $sessionID;
    return $session{member_id};    
}

sub isAdmin() {
    return 0 unless $sessionID;
    return 2 if index($session{access}||'', 'admin') >= 0;   
}

sub loginSession($) {
    my ($member_id) = @_;

    my $ares = db->sql("select id, doorAccess, adminAccess, realname, username from member where id=?", $member_id);
    my ($id, $door, $admin, $name,$username) = $ares->fetchrow_array;
    $ares->finish;

    die "Invalid member_id passed to loginSession: $member_id" unless $id and $id == $member_id;

    $session{member_id} = $id;
    $session{access} = 'login';
    $session{access} .= ',door' if $door;
    $session{access} .= ',admin' if $admin;
    $session{name} = $name;
    $session{username} = $username;
}

sub logoutSession() {
    delete $session{access};
    delete $session{member_id};
    delete $session{name};
}

sub clearSession() {
    %session = ();
    $sessionID = undef;
}

37;
