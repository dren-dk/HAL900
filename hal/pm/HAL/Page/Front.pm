#-*-perl-*-
package HAL::Page::Front;
use strict;
use warnings;
use utf8;

use HTML::Entities;
use Digest::SHA qw(sha1_hex);

use HAL;
use HAL::Pages;
use HAL::Session;
use HAL::Util;
use HAL::Email;

sub outputFrontPage($$$;$) {
    my ($cur, $title, $body, $feed) = @_;
    
    my @items = (
	{
	    link=>"/hal/",
	    name=>'index',
	    title=>'HAL:900',
	},
	);

    if (isLoggedIn) {
	push @items, (
	    {
		link=>"/hal/account/",
		name=>'account',
		title=>'Bruger Oversigt',
	    }
	);

	if (isAdmin) {
	    push @items, (
		{
		    link=>"/hal/admin/",
		    name=>'admin',
		    title=>'Admin',
		}
	    );
	}

    } else {
	push @items, (
	{
	    link=>"/hal/new",
	    name=>'new',
	    title=>'Ny bruger',
	},
	{
	    link=>"/hal/login",
	    name=>'login',
	    title=>'Login',
	},
	);
    }
    
    for my $i (@items) {
	$i->{current}=1 if $i->{name} eq $cur;
    }
    
    return {
	opt=>{
	    title=>$title,
	    feed=>$feed,
	    dontLinkLogo=>$cur eq 'index',
	    noFeedPage=>$cur eq 'news',
	},
	body=>$body,
	items=>\@items,         
    }
} 

sub mainIndexPage {
    my ($r,$q,$p) = @_;

    my $content = "<p>Velkommen til HAL:900, OSAAs medlemsdatabase som holder styr på medlemmer, økonomi og adgangskontrol.</p>";

    return outputFrontPage("index", "Velkommen", $content);
}

sub notFound {
    my ($r,$q,$p) = @_;

    return outputFrontPage("404", "Not found", 
      "<p>The page you are looking does not exist, it can only be attributable to human error.</p>");
}

sub noCookie {
    my ($r,$q,$p) = @_;

    if (getSessionID()) {
	my $session = getSession;
	my $wanted = $session->{wanted} || '/hal/';
	delete $session->{wanted};
	return outputGoto($wanted);
    } 

    return outputFrontPage("nocookie", "No cookie?", 
      "<p>You seem to have turned off cookie support, fix it KTHXBAI.</p>");
}

sub newUser {
    my ($r,$q,$p) = @_;

    my $error = '';
    if ($p->{email}) {

	my $res = db->sql("select passwd from member where email = ?", $p->{email});
	my ($inuse) = $res->fetchrow_array;
	$res->finish;
	my $ue = escape_url($p->{email});
       
	if ($inuse) {
	    $error = qq'Mail adressen er allerede i brug, <a href="/hal/login?id=$ue">log ind her</a>.';

	} elsif (validateEmail($p->{email})) {
	    my $key = sha1_hex($p->{email}.emailSalt());	    
	    my $email = sendmail('register@hal.osaa.dk', $p->{email},
				 'Fortsæt Open Space Aarhus registreringen',
"Klik her for at fortsætte registreringen som medlem af Open Space Aarhus:
https://hal.osaa.dk/hal/create?email=$ue&key=$key&ex=42

Hvis det ikke er dig der har startet oprettelsen af et medlemsskab hos OSAA,
så kan du enten ignorere denne mail eller sende os en mail på: bestyrelsen\@osaa.dk
"
		);

	    return outputFrontPage("new", "Opret nyt medlemsskab", 
				   "<p>Tak, vi har nu sendt en mail til ".encode_entities($p->{email}).
				   " med et link til resten af registreringen.</p>");
	} else {
	    $error = 'Mail adressen virker ikke.';	    
	}
    }
   
    my $form = qq'<form method="POST" action="/hal/new">';
    $form .= textInput("Email", "Indtast din mail adresse for at starte oprettelsen af et medlemsskab", 'email', $p);
    $form .= qq'<p class="error">$error</p>' if $error;

    $form .= '
<input type="submit" value="Videre">
</form>';

    return outputFrontPage("new", "Opret nyt medlemsskab", $form);
}

sub loginUser($$$) {
    my ($r,$q,$p) = @_;

    my $form = qq'<form method="POST" action="/hal/login">';

    my $errors = 0;

    $form .= textInput("Bruger navn",
		       "Indtast dit brugernavn eller din email adresse",
		       'username', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<2) {
	    $errors++;
	    return "Dit brugernavn skal være mindst 2 tegn langt";
	}
	return "";
    });
    $form .= passwdInput("Password",
			 "Indtast dit kodeord",
			 'passwd', $p);

    $form .= '
<hr>
<input type="submit" name="gogogo" value="Log på">
<input type="submit" name="bugger" value="Send mig en ny kode">
</form>';

    if ($p->{gogogo}) {
	if ($errors) {
	    $form .= "<p>Udfyld begge felter for at logge på!</p>";

	} else {
	    my $uRes = (db->sql('select id, passwd from member where lower(email)=? or lower(username)=?', lc $p->{username}, lc $p->{username}));
	    my ($id, $hash) = $uRes->fetchrow_array;
	    $uRes->finish;

	    if (!$p->{passwd}) {
		$form .= "<p>Brugeren med denne email adresse har ikke valgt et password, vi har sendt dig en mail med et link i, som du skal bruge for at fortsætte, check din inbox og spam folder.</p>";

	    } elsif ($id and passwordVerify($hash, $p->{passwd})) {

		loginSession($id);
		if (getSession->{wanted}) {
		    my $wanted = getSession->{wanted};
		    delete getSession->{wanted};
		    return outputGoto($wanted);
		} else {
		    return outputGoto('/hal/account');		
		}
	    } else {
		sleep(1+rand(10));
		$form .= "<p>Hmm, enten er der ingen bruger med det navn, eller også er koden forkert, prøv igen.</p>";
		if ($id) {
		    l "Failed login, wrong password for user id $id: $p->{username}";

		} else {
		    l "Failed login, wrong user id: $p->{username}";
		}
	    }
	}	    

    } elsif ($p->{bugger}) {
	my $uRes = (db->sql('select id,passwd from member where email=?', $p->{username}));
	my ($id,$passwd) = $uRes->fetchrow_array;
	$uRes->finish;

	if ($id) {
	    my $key = sha1_hex($p->{username}.$passwd);
	    my $ue = escape_url($p->{username});
    
	    my $email = sendmail('passwordreset@hal.osaa.dk', $p->{username},
				 'Nyt password til Open Space Aarhus medlemsdatabasen',
"En eller anden, måske dig, har bedt om at du skal have tilsendt et nyt password,
hvis du ønsker at få et nyt password kan du få dit gamle password nulstillet her:
https://hal.osaa.dk/hal/reset?email=$ue&key=$key&ex=43

Hvis det ikke er dig der har glemt dit password kan du roligt ignorere denne mail,
din konto er ikke blevet ændret.
"
		);
	    
	    $form .= "<p>Nu er der blevet sent en mail til dig med et link i, klik på linket for at skifte kode.</p>";
	    
	} else {
	    sleep(1+rand(10));
	    $form .= "<p>Hmm, der ser ikke ud til at være en bruger med den email adresse, prøv igen.</p>";
	    l "Failed password reset, wrong user id: $p->{username}";
	}
    }
    
    return outputFrontPage("login", "Log på systemet", $form);
}

sub resetPasswd {
    my ($r,$q,$p) = @_;

    my $email = $p->{email} || '';
    my $key = $p->{key} || '';

    my $res = db->sql("select id,passwd,username from member where email=?", $p->{email});
    my ($id,$passwd,$username) = $res->fetchrow_array;
    $res->finish;

    if (!$id) {
	l "Got request to /hal/reset with invalid email: email=$email";
	return outputGoto('/hal/');
    }

    my $correctKey = sha1_hex($email.$passwd);
    if ($key ne $correctKey) {
	l "Got request to /hal/reset with invalid email key: email=$email key=$key";
	return outputGoto('/hal/');
    }

    my $form = qq'
<p>Denne side kan skifte dit password, hvis du ikke ønsker at skifte dit password skal du forlade siden.</p>
<form method="POST" action="/hal/reset">';
    $form .= encode_hidden({
	 email=>$email,
	 key=>$key,
    });

    my $errors = 0;
    $form .= passwdInput2("Password",
		       "Dit password som skal give dig adgang til dette system, vælg noget du kan huske denne gang.",
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
	if (index(lc($v), lc($username)) >= 0) {
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

    $form .= '
<hr>
<input type="submit" name="gogogo" value="Skift mit password!">
</form>';

    if ($p->{gogogo}) {
	if ($errors) {
	    $errors = "en" if $errors == 1;
	    $form .= "<p>Hovsa, der er $errors fejl!</p>";
	} else {
	    if (db->sql('update member set passwd=? where id=?', passwordHash($p->{passwd}), $id)) {
		loginSession($id);

		return outputGoto('/hal/account');
	    } else {
		$form .= "<p>Hovsa, noget gik galt, prøv igen.</p>";		
	    }
	}	    
    }

    return outputFrontPage('reset', 'Skifter glemt password', $form);
}


BEGIN {
    addHandler(qr'^/hal/?$', \&mainIndexPage);
    addHandler(qr'^/hal/nocookie$', \&noCookie);
    addHandler(qr'^/hal/new$', \&newUser);
    addHandler(qr'^/hal/login$', \&loginUser);
    addHandler(qr'^/hal/reset$', \&resetPasswd);
    addHandler(qr'^/', \&notFound, 10000);
}

42;
