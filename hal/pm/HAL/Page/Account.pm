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
	    title=>'Skift Email',
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
	    title=>'Ret Detaljer',
	},
	{
	    link=>"/hal/account/rfid",
	    name=>'rfid',
	    title=>'Nøgle',
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
<table style="width: 100%"><tr><td>

<div class="floaty">
<h2>Detaljer [<a href="/hal/account/details">Ret</a>]</h2>
<p>
<strong>ID:</strong> $username<br>
$realname<br>
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

    my $okCount = 0;
    my $noPin = 0;
    my $rr = db->sql("select id, rfid, pin, lost from rfid where owner_id=?", getSession->{member_id})
	or die "Failed to fetch list of RFIDs for user";
    while (my ($id, $rfid, $pin, $lost) = $rr->fetchrow_array) {
	
	my $status = '';
	if ($lost) {
	    $status = qq'Tabt';
	} elsif ($pin) {
	    $status = qq'OK';
	    $okCount++;
	} else {
	    $status = qq'Mangler PIN kode'; 
	    $noPin = qq'/hal/account/rfid/$id';
	}

	$html .= qq'<li>RFID nøgle <a href="/hal/account/rfid/$id">$rfid [$status]</a></li>';
    }
    $rr->finish;

    if ($doorAccess) {
	
	if ($okCount) {
	    $html .= '<li>Du kan låse døren til lokalerne op med din RFID og PIN kode</li>';

	} elsif ($noPin) {
	    $html .= qq'<li>Du kunne låse døren til lokalerne op med din RFID, men du mangler <a href="$noPin">at vælge en pin kode</a>.</li>';
	    
	} else {
	    $html .= '<li>Du kunne låse døren til lokalerne op, hvis ellers du havde en RFID nøgle, kontakt <a href="mailto:kassereren@osaa.dk">kassereren@osaa.dk</a></li>';	    
	}

    } elsif ($memberDoorAccess) {
	$html .= '<li>Du kan ikke låse døren til lokalerne op, kontakt <a href="mailto:kassereren@osaa.dk">kassereren@osaa.dk</a></li>';

    } else {
	$html .= '<li>Du kan ikke låse døren til lokalerne op, <a href="/hal/account/type">opgrader til betalende medlem</a></li>';
    }

    $html .= $adminAccess ? '<li>Du kan administrere systemet</li>' : '';
    $html .= "</ul></div>\n";
    $html .= "<td></tr></table> <!-- Yes I'm using a table for layout, so sue me! -->";

    if ($monthlyFee > 0) {
	my $sugFee = $monthlyFee*6;
	$html .= "<h2>Kontingent</h2>
<p>Dit kontingent er $monthlyFee kr pr. måned. Betalingen foregår ved at lave en bankoverførsel med din email adresse (<strong>$email</strong>) i kommentarfeltet, så vi har pengene senest den første i hver måned.</p><p>Open Space Aarhus’ kontooplysninger er: <strong>Reg.nr.: 1982 Konto nr.: 0741891514</strong></p>
<p>Det anbefales at, om muligt, betale for et halvt år af gangen ($sugFee kr), da færre og større betalinger nedsætter administrationsomkostningerne og giver foreningen større økonomisk stabilitet.</p>";
    }
    
    my $ar = db->sql("select account.id, accountName, typeName, type_id ".
		     "from account inner join accounttype on (type_id=accounttype.id) ".
		     "where owner_id=? order by accounttype.id",
		     getSession->{member_id})
	or die "Failed to look up accounts owned by the user";

    while (my ($account_id, $accountName, $typeName, $type_id) = $ar->fetchrow_array) {
	my @table;
	my $tx = db->sql("select t.id, t.created, source_account_id, sa.accountName, target_account_id, ta.accountName, amount, comment ".
			 "from accountTransaction t ".
			 "inner join account sa on (t.source_account_id = sa.id) ".
			 "inner join account ta on (t.target_account_id = ta.id) ".
			 "where target_account_id=? or source_account_id=? ".
			 "order by t.id asc", $account_id, $account_id);
	my $sum = 0;
	my $sumIn = 0;
	my $sumOut = 0;
	while (my ($tid, $created, $source_id, $source, $target_id, $target, $amount, $comment) = $tx->fetchrow_array) {
	    my $other  = $source_id == $account_id ? $target : $source;
	    my $delta  = $source_id == $account_id ? $amount : -$amount;

	    $sum += $delta;

	    push @table, [$tid, $created, $comment, $other, $delta, $sum];
	}
	$tx->finish;

	@table = reverse @table;

	$html .= qq'<h2>$typeName: $accountName - Saldo: $sum</h2>';
	$html .= "<table><th>ID</th><th>Dato</th><th>Transaktion</th><th>Fra/Til konto</th><th>Beløb</th><th>Saldo</th>\n";
	my $count = 0;
	for my $r (@table) {
	    my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';
	    $html .= qq'<tr $class>'.join('', map {"<td>$_</td>"} @$r).qq'</tr>\n';
	}
	$html .= "</table>";
    }
    $ar->finish;

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

sub detailsPage {
    my ($r,$q,$p) = @_;

    my $form = '<form method="POST" action="/hal/account/details">';

    my $uRes = (db->sql('select username,realname, smail, phone from member where id=?', getSession->{member_id}));
    my ($username, $realname, $smail, $phone) = $uRes->fetchrow_array;
    $uRes->finish;
    
    my $errors = 0;

    $p->{username} ||= $username;
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

	if (lc($v) ne lc($username)) {
	    my $res = db->sql("select count(*) from member where lower(username)=?", lc($v));
	    my ($inuse) = $res->fetchrow_array;
	    $res->finish;
	    
	    if ($inuse) {
		$errors++;
		return "Det valgte brugernavn er allerede i brug, vælg et andet.";
	    }
	}
	return "";
    });
    
    $p->{name} ||= $realname;
    $form .= textInput("Fuldt navn", "Dit rigtige navn, incl. efternavn", 'name', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<4) {
	    $errors++;
	    return "Dit fulde navn kan umuligt være mindre end 4 tegn langt.";
	}
	if ($v !~ /^[a-zA-ZæøåÆØÅ \.-]+$/) {
	    $errors++;
	    return "Æh, hvad?";
	}
	if ($v !~ / /) {
	    $errors++;
	    return "Også efternavnet, tak.";
	}

	return "";
    });
    
    $p->{snailmail} ||= $smail;
    $p->{snailmail} =~ s/\s+$//s;
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
    
    $p->{phone} ||= $phone;
    $form .= textInput("Telefon nummer", "Dit telefon nummer som du helst vil ringes op på", 'phone', $p, sub {
	my ($v,$p,$name) = @_;
	$v =~ s/[^+\d]+//g;
	if (length($v)<8) {
	    $errors++;
	    return "Dit telefon nummer kan umuligt være kortere end 4 tal langt.";
	}
	return "";
    });

    $form .= '
<hr>
<input type="submit" name="gogogo" value="Gem mine oplysninger">
</form>';

    if ($p->{gogogo}) {
	if ($errors) {
	    $errors = "en" if $errors == 1;
	    $form .= "<p>Hovsa, der er $errors fejl!</p>";
	} else {
	    if (db->sql('update member set username=?, realname=?, smail=?, phone=? where id=?',
			               $p->{username}, $p->{name}, $p->{snailmail}, $p->{phone}, getSession->{member_id})) {
		l "Updated: username=$p->{username}, name=$p->{name}, snailmail=$p->{snailmail}, phone=$p->{phone}";
		return outputGoto('/hal/account');
	    } else {
		$form .= "<p>Hovsa, noget gik galt, prøv igen.</p>";		
	    }
	}	    
    }

    return outputAccountPage('details', 'Ret bruger oplysninger', $form);
}

sub rfidPage {
    my ($r,$q,$p,$rfid_id) = @_;
    
    if ($p->{lost}) {
	db->sql('update rfid set pin=null, lost=true where id=? and owner_id=?',
		$rfid_id, getSession->{member_id}) or die "Urgh";
	l "Marked rfid as lost rfid_id=$rfid_id";
    }
    if ($p->{found}) {
	db->sql('update rfid set pin=null, lost=false where id=? and owner_id=?',
		$rfid_id, getSession->{member_id}) or die "Urgh";
	l "Marked rfid as lost rfid_id=$rfid_id";
    }

    my $rr = db->sql("select rfid, pin, lost from rfid where owner_id=? and id=?",
		     getSession->{member_id}, $rfid_id)
	or die "Failed to fetch RFID for user $rfid_id";
    my ($rfid, $pin, $lost) = $rr->fetchrow_array;    
    $rr->finish;
    return outputGoto('/hal/account') unless $rfid;

    my $html = '';

    $html .= "<p>Din RFID nøgle har nummer <strong>$rfid</strong>.</p>";
    
    if ($lost) {
	$html .= qq'<p>Denne RFID nøgle kan ikke bruges, fordi den er markeret som tabt, hvis du har fundet den, så klik her: <a href="/hal/account/rfid/$rfid_id?found=1">Fundet!</a></p>';

    } else {
	if (!$pin) {
	    $html .= qq'<p>Denne RFID nøgle kan ikke bruges, fordi den ikke har nogen PIN kode.</p>';
	}

	$html .= qq'<form method="POST" action="/hal/account/rfid/$rfid_id">';

	my $errors = 0;
	$html .= passwdInput2("PIN kode",
			      "PIN koden gør det muligt at bruge RFID nøglen, den skal være mindst 5 cifre og må ikke være den samme som du bruger andre steder f.eks. på kredit kort.",
			      'pin', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<5) {
	    $errors++;
	    return "Din PIN kode skal være mindst 5 cifre langt";
	}
	if ($v !~ /^\d+$/) {
	    $errors++;
	    return "Din PIN kode må kun indeholde tal";
	}
	if ($v =~ /^0$/) {
	    $errors++;
	    return "Din PIN kode må ikke starte med 0";
	}
	if ($v =~ /(.+)\1/) {
	    $errors++;
	    return "Din PIN kode må ikke indeholde gentagelser";
	}
	my @v = split(//, $v);
	my $oc = 0;
	my $monoCount = 0;
	my $slope = 0;
	for my $c (@v) {
	    my $ns = $c-$oc;
	    $oc = $c;
	    if ($ns == $slope) {
		$monoCount++;
	    } else {
		$monoCount = 0;
	    }
	    $slope = $ns;
	    
	    if ($monoCount >= 2) {
		$errors++;
		return "Cifrene må ikke komme i rækkefølge";
	    }
	}
	if ($v ne $p->{"${name}_confirm"}) {
	    $errors++;
	    return "De to PIN koder skal være ens";
	}

	return "";
	});

	$html .= '
<hr>
<input type="submit" name="gogogo" value="Skift min PIN kode!">
</form>';


	if ($p->{gogogo}) {
	    if ($errors) {
		$html .= "<p>Hovsa, der er noget galt, prøv igen!</p>";
	    } else {
		if (db->sql('update rfid set pin=? where id=? and owner_id=?',
			    $p->{pin}, $rfid_id, getSession->{member_id})) {
		    l "Updated PIN for: rfid_id=$rfid_id";
		    $html .= "<p>Din PIN kode er nu opdateret i HAL, lige nu kan der gå en uge før ændringen slår igennem i dørlåsen.</p>";
		} else {
		    $html .= "<p>Hovsa, noget gik galt, prøv igen.</p>";		
		}
	    }	 
	}

	$html .= qq'<h2>Glemt PIN kode?</h2><p>Hvis du glemmer din PIN kode til din RFID nøgle, kan du altid bruge denne side til at vælge en ny kode.</p>';

	$html .= qq'<h2>Tabt nøgle?</h2><p>Hvis du har tabt RFID nøglen, kontakt <a href="mailto:kassereren\@osaa.dk">kassereren\@osaa.dk</a> så den kan blive markeret som tabt eller <a href="/hal/account/rfid/$rfid_id?lost=1">klik her for at markere den som tabt</a>, hvis du finder nøglen igen, kan du nemt markere den som fundet på denne side.</p>';
    }   

    return outputAccountPage('rfid', 'Ret RFID nøgle', $html);
}

sub rfidsPage {
    my ($r,$q,$p) = @_;

    my $html = '';

    my $list = '';
    my $lastId = 0;
    my $count = 0;
    my $rr = db->sql("select id, rfid, pin, lost from rfid where owner_id=? order by id", getSession->{member_id})
	or die "Failed to fetch list of RFIDs for user";
    while (my ($id, $rfid, $pin, $lost) = $rr->fetchrow_array) {

	my $status = '';
	if ($lost) {
	    $status = qq'Tabt';
	} elsif ($pin) {
	    $status = qq'OK';
	} else {
	    $status = qq'Mangler PIN kode'; 
	}

	$list .= qq'<li><a href="/hal/account/rfid/$id">$rfid [$status]</a></li>';
	$lastId = $id;
	$count++;
    }
    $rr->finish;

    return outputGoto("/hal/account/rfid/$lastId") if $count == 1;

    if ($list) {
	
	$html .= qq'<p>OSAA bruger RFID nøgler med PIN koder til at give adgang til lokalerne, klik et link for at se detaljer.</p>';

	$html .= "<ul>$list</ul>";

    } else {
	my $uRes = db->sql("select membertype.doorAccess, memberType, monthlyFee, username, email, phone, realname, smail, member.doorAccess, adminAccess ".
			   "from member, membertype where member.membertype_id=membertype.id and member.id=?",
			   getSession->{member_id});
	my ($memberDoorAccess, $memberType, $monthlyFee, $username, $email, $phone, $realname, $smail, $doorAccess, $adminAccess) = $uRes->fetchrow_array;
	$uRes->finish;
		
	if ($memberDoorAccess) {
	    $html .= qq'<p>Du har ingen registrerede RFID nøgler, kontakt <a href="mailto:kassereren\@osaa.dk">kassereren\@osaa.dk</a></p>';
	} else {
	    $html .= qq'<p>Du har ingen registrerede RFID nøgler.</p>';
	}
    }

    return outputAccountPage('rfid', 'RFID nøgler', $html);
}

BEGIN {
    ensureLogin(qr'^/hal/account');
    addHandler(qr'^/hal/account/?$', \&indexPage);
    addHandler(qr'^/hal/account/logout$', \&logoutPage);
    addHandler(qr'^/hal/account/email$', \&emailPage);
    addHandler(qr'^/hal/account/passwd$', \&passwdPage);
    addHandler(qr'^/hal/account/type$', \&typePage);
    addHandler(qr'^/hal/account/details$', \&detailsPage);
    addHandler(qr'^/hal/account/confirmemail$', \&emailConfirmPage);
    addHandler(qr'^/hal/account/rfid/(\d+)$', \&rfidPage);
    addHandler(qr'^/hal/account/rfid$', \&rfidsPage);
}

42;
