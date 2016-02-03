#-*-perl-*-
package HAL::Email;
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(sendmail validateEmail);

use strict;
use Net::SMTP;
use Data::Dumper;
use Carp;
use Encode;
use MIME::Entity;


# -----------------------------------------------------------------------
sub sendmail {
    my ($from, $to, $subject, $mail, $id) = @_;
    my $sender = '';
    if ($id) {
	$sender = "bouncer-$id\@hal.osaa.dk";
    } else {
	$id = 'none';
	$sender = $from;
    }

    my $entity = MIME::Entity->build(
				     Type => "text/plain",
				     Charset => "UTF-8",
				     Encoding => "quoted-printable",
				     Data => Encode::encode( "UTF-8", $mail ),
				     From => Encode::encode( "MIME-Header", $from),
				     To => Encode::encode( "MIME-Header", $to),
				     Subject => Encode::encode("MIME-Header", $subject),
				     'X-OSAA-email-id' => Encode::encode("MIME-Header", $id),
				     );
    my $server = 'localhost';
    my $smtp = Net::SMTP->new($server) or return "Unable to connect to: $server";
    $smtp->mail($sender)               or return $smtp->message;
    $smtp->recipient($to)              or return $smtp->message;
    $smtp->to($to)                     or return $smtp->message;
    $smtp->data()                      or return $smtp->message;
    my $msg = $entity->stringify;
    while ( $msg =~ m/([^\r\n]*)(\r\n|\n\r|\r|\n)?/g ) {
        my $line = ( defined($1) ? $1 : "" ) . "\r\n";
        $smtp->datasend( $line );
    }
    $smtp->dataend();
    $smtp->quit                            or return $smtp->message;;

    return 'Ok';
}

sub validateEmail {
    my $email = shift @_;
    return system("/home/hal/HAL900/hal/check-email", $email);
}

1;
