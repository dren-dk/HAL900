#-*-perl-*- $Id: Util.pm 3172 2006-12-22 19:58:04Z ff $
package HAL::Util;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(escape_url unescape_url encode_hidden randomdigits randomstring passwordHash passwordVerify);

use strict;
use warnings;
use HTML::Entities;
use Digest::SHA qw(sha256_hex);

# -----------------------------------------------------------------------
my %escapes;
for (0..255) {
    $escapes{chr($_)} = sprintf("%%%02X", $_);
}

# -----------------------------------------------------------------------
sub escape_url($) {
    my ($value) = @_;
    $value =~ s/([^a-zA-Z0-9])/$escapes{$1}/g;
    return $value;
}

sub unescape_url($) {
    my ($value) = @_;
    $value =~ s/\%([0-9A-Fa-f]{2})/chr(oct('0x'.$1))/ge;
    return $value;
}

sub encode_hidden($) {
    my ($f) = @_;
    return '' unless defined $f;
    my $o = '';
    while (my ($field,$value) = each %$f) {
	my $v = encode_entities($value);
	$o .= qq|<input type="hidden" name="$field" value="$v">\n|;
    }
    return $o;
}

sub randomstring($) {
  my ($length) = @_;
  my $data;

  local *FILE;
  open (FILE, "</dev/urandom") or die "Couldn't read from /dev/urandom";
  read(FILE, $data, $length) or die "Couldn't read from /dev/urandom";
  close FILE;
  return sprintf ("%02x" x $length, unpack ("C$length", $data));
}

sub randomdigits($) {
    my ($length) = @_;
    
    my $data;
    local *FILE;
    open (FILE, "</dev/urandom") or die "Couldn't read from /dev/urandom";
    read(FILE, $data, $length) or die "Couldn't read from /dev/urandom";
    close FILE;
    
    my $out;
    for my $i (0..$length-1) {
	$out .= int(ord(substr($data,$i,1))/25.6);
    }
    return $out;
}

sub passwordHash($) {
    my $passwd = shift;
    
    my $salt = randomstring(10);
    return join ':', 'sha256', $salt, sha256_hex("$salt:$passwd");
}

sub passwordVerify($$) {
    my ($hash, $passwd) = @_;

    my ($scheme, $salt, $h) = split /:/, $hash;
    die "Unknown password scheme $scheme" unless $scheme eq 'sha256';

    return sha256_hex("$salt:$passwd") eq $h ? 1 : 0;   
}

1;

