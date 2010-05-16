#-*-perl-*- $Id: Util.pm 3172 2006-12-22 19:58:04Z ff $
package HAL::Util;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(escape_url unescape_url encode_hidden);

use strict;
use warnings;
use HTML::Entities;

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

1;

