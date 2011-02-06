#-*-perl-*-
package HAL::TypeAhead;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(typeAhead);
use strict;
use warnings;
use POSIX;
use utf8;
use HTML::Entities;

sub typeAhead {
    my ($fieldName, $default, $search) = @_;

    my $id = $fieldName.'_ta';
    my $ed = encode_entities($default);
    my $events = qq!onblur="taBlur('$id','$search')" onkeypress="taKey('$id', '$search', event)"!;
    return qq!<input type="input" size="50" name="$fieldName" id="$id" autocomplete="off" $events/>!.
	qq!<input type="hidden" name="$fieldName-id" id="$id-id" value="$ed"/>!;
}
