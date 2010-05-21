#-*-perl-*-
package HAL::Page::Account;
use strict;
use warnings;
use utf8;

use Data::Dumper;
use HTML::Entities;
use Email::Valid;
use Digest::SHA qw(sha1_hex);

use HAL;
use HAL::Pages;
use HAL::Session;
use HAL::Util;
use HAL::Email;

sub outputAccountPage($$$;$) {
    my ($cur, $title, $body, $feed) = @_;
    
    my @items = (
	{
	    link=>"/hal/account/",
	    name=>'index',
	    title=>'Oversigt',
	},
	{
	    link=>"/hal/account/email",
	    name=>'email',
	    title=>'Skift email',
	},
	{
	    link=>"/hal/account/passwd",
	    name=>'passwd',
	    title=>'Skift Password',
	},
	{
	    link=>"/hal/account/type",
	    name=>'type',
	    title=>'Medlemstype',
	},
	{
	    link=>"/hal/account/details",
	    name=>'details',
	    title=>'Ret adresse',
	},
	);
    
    for my $i (@items) {
	$i->{current}=1 if $i->{name} eq $cur;
    }
    
    return {
	opt=>{
	    title=>$title,
	    feed=>$feed,
	    noFeedPage=>$cur eq 'news',
	},
	body=>$body,
	items=>\@items,         
    }
} 

sub indexPage {
    my ($r,$q,$p) = @_;

    my $uRes = db->sql("select membertype.doorAccess, memberType, monthlyFee, username, email, phone, realname, smail, member.doorAccess, adminAccess ".
		       "from member, membertype where member.membertype_id=membertype.id and member.id=?",
		       getSession->{member_id});
    my ($memberDoorAccess, $memberType, $monthlyFee, $username, $email, $phone, $realname, $smail, $doorAccess, $adminAccess) = $uRes->fetchrow_array;
    $uRes->finish;

    $smail =~ s/[\n\r]+/<br>/g;

    my $html = qq'
<div class="floaty">
<h2>Navn og adresse [<a href="/hal/account/details">Ret</a>]</h2>
<p>$realname<br>
$smail<br>
Tlf. $phone
</p>
</div>

<div class="floaty">
<h2>Email [<a href="/hal/account/email">Ret</a>]</h2>
<p>$email</p>
</div>

<div class="floaty">
<h2>Medlems type [<a href="/hal/account/type">Ret</a>]</h2>
<p>$memberType ($monthlyFee kr/måned)</p>
</div>

<div class="floaty">
<h2>Privilegier</h2>
<ul>
';
    
    $html .= $doorAccess 
	? '<li>Du kan låse døren til lokalerne op</li>' 
	: $memberDoorAccess 
	   ? '<li>Du kan ikke låse døren til lokalerne op, kontakt <a href="mailto:kasseren@osaa.dk">kasseren@osaa.dk</a></li>'
	   : '<li>Du kan ikke låse døren til lokalerne op, <a href="/hal/account/type">opgrader til betalende medlem</a></li>';
    $html .= $adminAccess ? '<li>Du kan administrere systemet</li>' : '';
    $html .= "</ul></div>\n";

    return outputAccountPage('index', 'Oversigt', $html);
}

sub logoutPage {
    my ($r,$q,$p) = @_;

    logoutSession();
    return outputGoto('/hal/');
}

sub emailPage {
    my ($r,$q,$p) = @_;

    my $html = '';

    $html = qq'<form method="POST" action="/hal/account/email">';

    my $errors = 0;

    $html .= textInput("Email",
		       "Indtast din nye email adresse, vi sender en mail til adressen med et link du skal klikke på for at fortsætte.",
		       'email', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<2) {
	    $errors++;
	    return "Din email adresse kan da umuligt være så kort";
	}

	my $res = db->sql("select count(*) from member where email = ?", $p->{email});
	my ($inuse) = $res->fetchrow_array;
	$res->finish;
	my $ue = escape_url($p->{email});

	if ($inuse) {
	    $errors++;
	    return qq'Mail adressen er allerede i brug.';

	} elsif (!eval { Email::Valid->address(-address => $p->{email},-mxcheck => 1) }) {
	    $errors++;
	    return qq'Mail adressen er ugyldig, prøv igen.';	    
	}	

	return "";
    });

    $html .= '
<hr>
<input type="submit" name="gogogo" value="Skift til denne email adresse!">
</form>';

    if ($p->{gogogo}) {
	if ($errors) {
	    $errors = "en" if $errors == 1;
	    $html .= "<p>Hovsa, der er $errors fejl!</p>";

	} else {
	    my $uRes = (db->sql('select username,email,passwd from member where id=?', getSession->{member_id}));
	    my ($userName, $oldMail, $passwd) = $uRes->fetchrow_array;
	    $uRes->finish;

	    my $key = sha1_hex($p->{email}.$passwd);
	    my $ue = escape_url($p->{email});
	    my $uu = escape_url($userName);
    
	    my $email = sendmail('changeemail@hal.osaa.dk', $p->{username},
				 'Skift af email for dit Open Space Aarhus medlemsskab',
"En eller anden, måske dig, har bedt om at skifte din email adresse fra $oldMail til $p->{email}.
Hvis du ønsker at skifte til den nye adresse klik her:
https://hal.osaa.dk/hal/account/confirmemail?user=$uu&email=$ue&key=$key&ex=44

Hvis det ikke er dig der har bedt om at få denne mail kan du roligt ignorere denne mail,
hvis du er medlem af OSAA er din konto er ikke blevet ændret.
"
		);
	    l "Email-change: $oldMail -> $p->{email}: https://hal.osaa.dk/hal/account/confirmemail?user=$uu&email=$ue&key=$key&ex=44";

	    sendmail('changeemail@hal.osaa.dk', $p->{username},
				 'Skift af email for dit Open Space Aarhus medlemsskab',
"En eller anden, måske dig, har bedt om at skifte din email adresse fra $oldMail til $p->{email}.

Hvis det ikke er dig der har bedt om at skifte mail adresse, så har nogen fået adgang til din
konto og du bør logge ind og skifte dit password, lige nu.

Når du har skiftet dit password så kontakt bestyrelsen\@osaa.dk for at få undersøgt problemet.
"
		);
	    
	    $html .= "<p>Nu er der blevet sent en mail til dig med et link i, klik på linket for at skifte email adresse.</p>";	    
	}
    }

    return outputAccountPage('email', 'Skift email', $html);
}

sub emailConfirmPage {
    my ($r,$q,$p) = @_;

    my $uRes = (db->sql('select id,email,passwd from member where username=?', $p->{user}));
    my ($id, $oldMail, $passwd) = $uRes->fetchrow_array;
    $uRes->finish;

    if ($id != getSession->{member_id}) {
	logoutSession();
	getSession()->{wanted} = $r->unparsed_uri;
	return outputGoto("/hal/login");
    }

    my $key = sha1_hex($p->{email}.$passwd);
    if ($key ne $p->{key}) {
	l "Invalid key for email change from $oldMail to $p->{email}";
	return outputGoto("/hal/account");	
    } elsif ($p->{gogogo} and $p->{doit}) {

	if (db->sql('update member set email=? where id=?', $p->{email}, $id)) {
	    
	    return outputGoto('/hal/account/');
	} else {
	    
	    return outputGoto('/hal/account/');
	    l "Failed to change email address";
	}	
    }
    
    my $html = '<form method="POST" action="/hal/account/confirmemail">';

    $html .= encode_hidden({
	 email=>$p->{email},
	 key=>$p->{key},
	 user=>$p->{user},	 
    });

    $html .= qq'
<p>
For at skifte din mail adresse sæt kryds her og tryk skift min mail knappen.
</p>

<input type="checkbox" value="18" name="doit">Skift min email adresse fra $oldMail til <strong>$p->{email}</strong>

<hr>
<input type="submit" name="gogogo" value="Skift til denne email adresse!">
</form>';

    return outputAccountPage('email', 'Skift email', $html);
}

sub passwdPage {
    my ($r,$q,$p) = @_;

    my $uRes = (db->sql('select passwd,username from member where id=?', getSession->{member_id}));
    my ($passwd, $username) = $uRes->fetchrow_array;
    $uRes->finish;

    my $key = sha1_hex($passwd);

    my $form = qq'
<p>Denne side kan skifte dit password, hvis du ikke ønsker at skifte dit password skal du blot forlade siden.</p>
<form method="POST" action="/hal/account/passwd">';
    $form .= encode_hidden({
	 key=>$key,
    });

    my $errors = 0;
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

    if ($p->{gogogo} and $key eq $p->{key}) {
	if ($errors) {
	    $errors = "en" if $errors == 1;
	    $form .= "<p>Hovsa, der er $errors fejl!</p>";
	} else {
	    if (db->sql('update member set passwd=? where id=?', passwordHash($p->{passwd}), getSession->{member_id})) {
		$form = "<p>Dit password er blevet skiftet.</p>";
	    } else {
		$form .= "<p>Hovsa, noget gik galt, prøv igen.</p>";		
	    }
	}	    
    }

    return outputAccountPage('passwd', 'Skift Password', $form);
}

sub typePage {
    my ($r,$q,$p) = @_;

    my $form = '<form method="POST" action="/hal/account/type">';

    my $uRes = (db->sql('select membertype_id from member where id=?', getSession->{member_id}));
    my ($membertype_id) = $uRes->fetchrow_array;
    $uRes->finish;
    
    my @types;
    my $typesRes = db->sql('select id, memberType, monthlyFee, doorAccess from memberType order by id');
    while (my ($id, $memberType, $monthlyFee, $doorAccess) = $typesRes->fetchrow_array) {
	push @types, {
	    key=>$id,
	    name=>"$memberType ($monthlyFee kr/måned) ".($doorAccess ? '- Inkluderer nøgle til lokalerne' : '- Uden nøgle til lokalerne'),
	}
    }
    $typesRes->finish;
    
    $p->{membertype} ||= $membertype_id;

    my $errors = 0;
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
<input type="submit" name="gogogo" value="Skift min medlemstype!">
</form>';

    if ($p->{gogogo}) {
	if ($errors) {
	    $errors = "en" if $errors == 1;
	    $form .= "<p>Hovsa, der er $errors fejl!</p>";
	} else {
	    if (db->sql('update member set membertype_id=? where id=?',
			$p->{membertype}, getSession->{member_id})) {
		
		return outputGoto('/hal/account');
	    } else {
		$form .= "<p>Hovsa, noget gik galt, prøv igen.</p>";		
	    }
	}	    
    }

    return outputAccountPage('type', 'Skift Medlemstype', $form);
}

BEGIN {
    ensureLogin(qr'^/hal/account');
    addHandler(qr'^/hal/account/?$', \&indexPage);
    addHandler(qr'^/hal/account/logout$', \&logoutPage);
    addHandler(qr'^/hal/account/email$', \&emailPage);
    addHandler(qr'^/hal/account/passwd$', \&passwdPage);
    addHandler(qr'^/hal/account/type$', \&typePage);
    addHandler(qr'^/hal/account/confirmemail$', \&emailConfirmPage);
}

42;
