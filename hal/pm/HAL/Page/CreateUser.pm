#-*-perl-*-
package HAL::Page::Front;
use strict;
use warnings;
use utf8;

use HTML::Entities;
use Email::Valid;
use Digest::SHA qw(sha1_hex);

use HAL;
use HAL::Pages;
use HAL::Session;
use HAL::Util;
use HAL::Email;

sub createUser {
    my ($r,$q,$p) = @_;

    my $email = $p->{email} || '';
    my $key = $p->{key} || '';
    my $correctKey = sha1_hex($email.emailSalt());
    if ($key ne $correctKey) {
	l "Got request to /hal/create with invalid email key: email=$email key=$key";
	return outputGoto('/hal/');
    }
 
    my $form = qq'<form method="POST" action="/hal/create">';
    $form .= encode_hidden({
	 email=>$email,
	 key=>$key,
    });

    my $errors = 0;

    $form .= textInput("Bruger navn", "Dit bruger navn i dette system", 'username', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<2) {
	    $errors++;
	    return "Dit brugernavn skal være mindst 2 tegn langt";
	}
	if ($v !~ /^[A-Za-z0-9\.\@-]+$/) {
	    $errors++;
	    return "Dit brugernavn må kun bestå af: A-Z, a-z, 0-9 samt tegnene . \@ og -";
	}

	my $res = db->sql("select count(*) from member where username=?", $v);
	my ($inuse) = $res->fetchrow_array;
	$res->finish;

	if ($inuse) {
	    $errors++;
	    return "Det valgte brugernavn er allerede i brug, vælg et andet.";
	}
	return "";
    });
    
    $form .= textInput("Fuldt navn", "Dit rigtige navn, incl. efternavn", 'name', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<4) {
	    $errors++;
	    return "Dit fulde navn kan umuligt være mindre end 4 tegn langt.";
	}
	if ($v =~ /[\d\@]/) {
	    $errors++;
	    return "Æh, hvad?";
	}
	if ($v !~ / /) {
	    $errors++;
	    return "Også efternavnet, tak.";
	}

	return "";
    });
    
    $p->{smail} ||= '';
    $p->{smail} =~ s/\s+$//;
    $form .= areaInput("Snailmail", "Din post adresse, incl. gade, husnummer, by og postnummer", 'smail', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<4) {
	    $errors++;
	    return "Din adresse kan umuligt være mindre end 4 tegn lang.";
	}
	my @lines = split /\s*\n\s*/, $v;
	if (@lines < 2) {
	    $errors++;
	    return "Skriv venligst post adressen som den normalt står på et brev.";
	}

	return "";
    });
    
    $form .= textInput("Telefon nummer", "Dit telefon nummer som du helst vil ringes op på", 'phone', $p, sub {
	my ($v,$p,$name) = @_;
	$v =~ s/[^+\d]+//g;
	if (length($v)<8) {
	    $errors++;
	    return "Dit telefon nummer kan umuligt være kortere end 4 tal langt.";
	}
	return "";
    });

    #   passwd varchar(50), /* sha1 of "$id-$password" */       

    $form .= '
<input type="submit" name="gogogo" value="Opret mig!">
</form>';

    if ($p->{gogogo}) {
	$form .= "<p>Errors: $errors</p>";
    }
    
    return {
	opt=>{
	    title=>"Opretter medlemsskab",
	},
	body=>$form,
	#items=>\@items,
    };
}


BEGIN {
    addHandler(qr'^/hal/create$', \&createUser);
}

42;
