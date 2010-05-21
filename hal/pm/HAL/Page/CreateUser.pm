#-*-perl-*-
package HAL::Page::CreateUser;
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


    my $res = db->sql("select count(*) from member where email = ?", $p->{email});
    my ($inuse) = $res->fetchrow_array;
    $res->finish;
    return outputGoto("/hal/login?username=".escape_url($p->{email})) if $inuse;

 
    my $form = qq'<form method="POST" action="/hal/create">';
    $form .= encode_hidden({
	 email=>$email,
	 key=>$key,
    });

    my $errors = 0;

    $form .= textInput("Bruger navn",
		       "Dit bruger navn i dette system, vælg gerne det samme som i andre systemer (F.eks. Wiki og Wordpress)",
		       'username', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<2) {
	    $errors++;
	    return "Dit brugernavn skal være mindst 2 tegn langt";
	}
	if ($v !~ /^[A-Za-z0-9\.-]+$/) {
	    $errors++;
	    return "Dit brugernavn må kun bestå af: A-Z, a-z, 0-9 samt tegnene . og -";
	}

	my $res = db->sql("select count(*) from member where lower(username)=?", lc($v));
	my ($inuse) = $res->fetchrow_array;
	$res->finish;

	if ($inuse) {
	    $errors++;
	    return "Det valgte brugernavn er allerede i brug, vælg et andet.";
	}
	return "";
    });

    $form .= passwdInput2("Password",
		       "Dit password som skal give dig adgang til dette system.",
		       'passwd', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<6) {
	    $errors++;
	    return "Dit password skal være mindst 6 tegn langt";
	}
	if ($v !~ /[A-ZÆØÅ]/) {
	    $errors++;
	    return "Dit password skal indeholde mindst et stort bogstav";
	}
	if ($v !~ /[a-zæøå]/) {
	    $errors++;
	    return "Dit password skal indeholde mindst et lille bogstav";
	}
	if ($v !~ /\d/) {
	    $errors++;
	    return "Dit password skal indeholde mindst et tal";
	}
	if (index(lc($v), lc($p->{username})) >= 0) {
	    $errors++;
	    return "Dit password må ikke indeholde dit brugernavn";
	}
	if (index(lc($v), 'osaa') >= 0) {
	    $errors++;
	    return "Dit password må ikke indeholde osaa";
	}
	if ($v ne $p->{"${name}_confirm"}) {
	    $errors++;
	    return "De to passwords skal være ens";
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
    $p->{smail} =~ s/\s+$//s;
    $form .= areaInput("Snailmail", "Din post adresse, incl. gade, husnummer, by og postnummer", 'snailmail', $p, sub {
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

    my @types;
    my $typesRes = db->sql('select id, memberType, monthlyFee, doorAccess from memberType order by id');
    while (my ($id, $memberType, $monthlyFee, $doorAccess) = $typesRes->fetchrow_array) {
	push @types, {
	    key=>$id,
	    name=>"$memberType ($monthlyFee kr/måned) ".($doorAccess ? '- Inkluderer nøgle til lokalerne' : '- Uden nøgle til lokalerne'),
	}
    }
    $typesRes->finish;

    $form .= radioInput("Medlems type", "Vælg den type medlemsskab du ønsker", 'membertype', $p, sub {
	my ($v,$p,$name) = @_;
	unless ($v) {
	    $errors++;
	    return "Vælg venligst hvilken type medlemsskab du ønsker";
	}
	return "";
    }, @types);

    $form .= '
<hr>
<input type="submit" name="gogogo" value="Opret mig!">
</form>';

    if ($p->{gogogo}) {
	if ($errors) {
	    $errors = "en" if $errors == 1;
	    $form .= "<p>Hovsa, der er $errors fejl!</p>";
	} else {
	    if (db->sql('insert into member (membertype_id, username, email, passwd, phone, realname, smail) values (?,?,?,?,?,?,?)',
			$p->{membertype}, $p->{username}, $p->{email},
			passwordHash($p->{passwd}), $p->{phone}, $p->{name}, $p->{snailmail})) {
		
		my $idRes = db->sql("select currval(pg_get_serial_sequence('member', 'id'))");
		my ($id) = $idRes->fetchrow_array;
		$idRes->finish;
		loginSession($id);

		return outputGoto('/hal/account');
	    } else {
		$form .= "<p>Hovsa, noget gik galt, prøv igen.</p>";		
	    }
	}	    
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
