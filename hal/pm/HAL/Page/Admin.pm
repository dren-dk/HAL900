#-*-perl-*-
package HAL::Page::Admin;
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
use HAL::TypeAhead;

sub outputAdminPage($$$;$) {
    my ($cur, $title, $body, $feed) = @_;
    
    my @items = (
	{
	    link=>"/hal/admin/",
	    name=>'index',
	    title=>'Admin',
	},
	{
	    link=>"/hal/admin/members",
	    name=>'members',
	    title=>'Medlemmer',
	},
	{
	    link=>"/hal/admin/load",
	    name=>'load',
	    title=>'Load poster',
	},
	{
	    link=>"/hal/admin/consolidate",
	    name=>'consolidate',
	    title=>'Konsolider',
	    js=>1,
	},
	{
	    link=>"/hal/admin/accounts",
	    name=>'accounts',
	    title=>'Konti',
	},
	);
    
    my $js;
    my $onload;
    
    for my $i (@items) {
	if ($i->{name} eq $cur) {
	    $i->{current}=1;
	    if ($i->{js}) {
		$js = "$cur.js";
		$onload = "init_$cur();";
	    }
	}
    }
    
    return {
	opt=>{
	    title=>$title,
	    feed=>$feed,
	    noFeedPage=>$cur eq 'news',
	    js=>$js,
	    onload=>$onload,
	},
	body=>$body,
	items=>\@items,         
    }
} 

sub indexPage {
    my ($r,$q,$p) = @_;

    my $html = '<p>Todo: Lav en oversigt...</p>';

    return outputAdminPage('index', 'Hoved konti', $html);
}

sub loadPage {
    my ($r,$q,$p) = @_;

    my $msg = '<p class="lead">Vælg den csv fil <a href="https://www.netbank.nordea.dk/netbank/index_bu.jsp">Nordeas Konto-kig</a> exporterede.</p>';

    if ($p->{gogo}) {
	my $f = $q->upload('uploadfile');
	my $data = join('', <$f>);
	utf8::upgrade($data);

#	l "Upgraded:\n$data\n";
	
	db->sql('insert into bankBatch (rawCsv) values (?)', $data) or die "Failed to store the csv: $data";
	my $batchID = db->getID('bankBatch');

#	l "Got file: $data\n";

	my @txn;
	for my $line (split /\n/, $data) {
	    my ($date, $text, $date2, $amount, $sum) = split(/;/, $line);
	    next unless $date;
	    next if $date eq 'Bogført';
	    next unless $amount;
	    next unless $text;

	    $amount =~ s/\.//g;
	    $amount =~ s/,/./;
	    $sum =~ s/\.//g;
	    $sum =~ s/,/./;
	    $text =~ s/\s\s+([A-ZÆØÅ])/ $1/;
	    $text =~ s/\s\s+([^A-ZÆØÅ])/$1/;
	    $text =~ s/^Bgs //;
	    $text =~ s/[<&]/_/g;

	    unshift @txn, {
		date=>$date,
		text=>$text,
		amount=>$amount,
		sum=>$sum,
	    };
	}

	$msg = "<p>Fandt ".scalar(@txn)." transaktioner i filen:</p>";

	$msg .= "<table><tr><th>Dato</th><th>Tekst</th><th>Beløb</th><th>Status</th></tr>\n";
	my $new = 0;
	my $count = 0;
	for my $t (@txn) {
	    my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';

	    my $res = db->sql("select count(*) from bankTransaction where bankDate=? and bankComment=? and amount=? and bankSum=?",
			      $t->{date}, $t->{text}, $t->{amount}, $t->{sum});
	    my ($dup) = $res->fetchrow_array;
	    $res->finish;

	    if ($dup) {
		$msg .= "<tr $class><td>$t->{date}</td><td>$t->{text}</td><td>$t->{amount}</td><td>Duplet, ignoreret.</td></tr>\n";
	    } else {
		$msg .= "<tr $class><td>$t->{date}</td><td>$t->{text}</td><td>$t->{amount}</td><td>Ny</td></tr>\n";

		db->sql("insert into bankTransaction (bankBatch_id, bankDate, bankComment, amount, bankSum) values (?,?,?,?,?)",
			$batchID, $t->{date}, $t->{text}, $t->{amount}, $t->{sum}) or die "Failed to insert transaction: ".Dumper($t);
		$new++;
	    }
	}
	$msg .= "</table>";

	if ($new) {
	    $msg .= qq'<p>Fandt $new transaktioner, <a href="/hal/admin/consolidate">konsolider dem nu</a>.</p>';
	} else {
	    $msg .= qq'<p>Ingen nye transaktioner fundet.</p>';
	}
    }

    my $html = qq'
<h4>CSV fil</h4>
$msg

<form method="post" enctype="multipart/form-data" action="/hal/admin/load">

<input type="file" name="uploadfile">
<hr>
<input type="submit" name="gogo" value="Upload">
</form>';

    return outputAdminPage('load', 'Load poster', $html);
}

sub consolidatePage {
    my ($r,$q,$p) = @_;

    # Gets all the account types.
    my $rest = db->sql("select id, typename from accounttype where id <> 1 order by id") 
	or die "Failed to get list of account types transactions";    
    my @types;
    while (my ($id, $typename) = $rest->fetchrow_array) {
	push @types, {id=>$id, name=>$typename};
    }
    $rest->finish;

    if ($p->{gogogo}) {
	my $res = db->sql("select id, amount, userComment, bankDate, bankComment from bankTransaction where transaction_id is null") 
	    or die "Failed to get unconsolidated transactions";

	while (my ($id, $amount, $userComment, $bankDate, $bankComment) = $res->fetchrow_array) {
	    my $comment = $p->{"comment_$id"} // '';
	    if ($comment ne ($userComment // '')) {
		db->sql("update bankTransaction set userComment=? where id=?", $comment, $id) 
		    or die "Failed to update comment on $id to $comment";
	    }
#	    l "Looking at: $id ".Dumper($p);
	    my $type_id    = $p->{"type_$id"} or next;
	    my $account_id = $p->{"account_$id"} or next;
#	    l "Looking at: $type_id $account_id";
	    
	    if ($account_id < 0) {
		my $dude_id = -$account_id;
		my $ar = db->sql("select id from account where owner_id=? and type_id=?",
		    $dude_id, $type_id);
		($account_id) = $ar->fetchrow_array;
		$ar->finish;
		
		unless ($account_id) {
		    my $dr = db->sql("select realname, email from member where id=?", $dude_id);
		    my ($name, $email) = $dr->fetchrow_array or die "Invalid member id: $dude_id";
		    $dr->finish;

		    db->sql('insert into account (owner_id, type_id, accountName) values (?,?,?)',
			    $dude_id, $type_id, $name) or die "Failed to store the new account";
		    $account_id = db->getID('account') or die "Failed to get new account id";
		    l "Created account $account_id for $dude_id type: $type_id";
		}
	    }

	    my @accounts = ($account_id, 1);
	    if ($amount < 0) {
		$amount *= -1;
		@accounts = reverse @accounts;
	    }

	    db->sql('insert into accountTransaction (source_account_id, target_account_id, amount, comment) values (?, ?, ?, ?)',
		    @accounts, $amount, "$bankDate: $bankComment"
		) or die "Failed to insert transaction ".join(',', @accounts, $amount, "$bankDate: $bankComment");
	    my $transaction_id = db->getID('accountTransaction') or die "Failed to get new transaction id";
	    db->sql("update bankTransaction set transaction_id=? where id=?", $transaction_id, $id)
		or die "Failed to update bankTransaction to set transaction_id=$transaction_id for $id";
	}

	$res->finish;
    }


    my $html = '';
    my $load = '';

    my $res = db->sql("select id,bankDate, bankComment, amount, userComment from bankTransaction where transaction_id is null order by id") 
	or die "Failed to get unconsolidated transactions";
    $html .= '

<form method="post" action="/hal/admin/consolidate">

<table id="dirty">
<tr><th>Dato</th><th>Tekst</th><th>Beløb</th><th>Løsning</th><th>Kommentar</th></tr>
';

    my %txn;
    my $count = 0;
    while (my ($id, $bankDate, $bankComment, $amount, $userComment) = $res->fetchrow_array) {
	my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';
	my $t = $txn{$id};

	my $ev = encode_entities($userComment||'');
	my $uc = qq'<input name="comment_$id" id="comment_$id" type="text" size="10" value="$ev"/>';
	my $sc = qq'<select name="type_$id" id="type_$id" onchange="changetype($id)">\n';
	$sc .= qq'  <option value="0">Unknown</option>\n';
	for my $type (@types) {
	    $sc .= qq'  <option value="$type->{id}">$type->{name}</option>\n';
	}
	$sc .= "</select>\n";

	$sc .= qq'<select name="account_$id" id="account_$id">\n';
	$sc .= qq'  <option value="0">Unknown</option>\n';
	$sc .= "</select>\n";
	$html .= qq'<tr $class><td>$bankDate</td><td>$bankComment</td>'.
	         qq'<td class="numeric">$amount</td><td>$sc</td><td>$uc</td></tr>';

	$bankComment =~ s/[^a-zA-ZæøåÆØÅ0-9\.\@-]+/ /g;
	$bankComment = lc($bankComment);
	$load .= qq' txn($id,"$bankComment");\n';
    }
    $res->finish;
        
    my %seen;    
    my $atres = db->sql("select owner_id, id, type_id, accountName from account order by accountName")
	or die "Failed to get unconsolidated transactions";
    while (my ($owner_id, $id, $type_id, $accountName) = $atres->fetchrow_array) {
	$load .= qq' account($id, $type_id, "$accountName");\n';
	$seen{$owner_id}{$type_id} = $id if $owner_id;
    }
    $atres->finish;

    my $mres = db->sql("select id, email, realname from member order by realname")
	or die "Failed to get unconsolidated transactions";
    while (my ($id, $email, $name) = $mres->fetchrow_array) {
	for my $type (2,3) {
	    my $aid = $seen{$id}{$type} || -$id;
	    if ($aid < 0) { # Add fake account.
		$load .= qq' account($aid, $type, "[$name <$email>]");\n';
	    }
	    $name = lc($name);
	    $email = lc($email);
	    $load .= qq' dude($aid, $type, "$email", "$name");\n';
	}
    }
    $mres->finish;

    
    $html .= qq'
</table>

<br/>
<input type="submit" name="gogogo" value="Gem alt"/>

</form>

<script type="text/javascript">
$load
</script>
';

    if ($count == 0) {
	$html = "<p>Der er ingen udestående bank transaktioner.</p>";	
    }

    return outputAdminPage('consolidate', 'Konsolider poster', $html);
}

sub selector {
    return join ' - ', map {
	$_->{current} ? "<strong>$_->{title}</strong>" : qq'<a href="$_->{href}">$_->{title}</a>'
    } @_;
}

sub accountsPage {
    my ($r,$q,$p, $type_id) = @_;
    $type_id ||= 0;

    my $rest = db->sql("select id, typename from accounttype order by id") 
	or die "Failed to get list of account types";    
    my @types;
    my $title = 'Konti';
    while (my ($id, $typename) = $rest->fetchrow_array) {
	push @types, {
	    href=>"/hal/admin/accounts/$id",
	    title=>$typename,
	    current=>$id==$type_id,
	};
	$title = "Konti : $typename" if $id==$type_id;
    }
    $rest->finish;

    my $html = '<p>Konto type: '.selector(@types).'</p>';
    if ($type_id) {
	$html .= qq'
<table>
<tr><th>Konto ID</th><th>Konto navn</th><th>Ejer</th><th>Saldo</th></tr>
';
	my $ar = db->sql("select account.id, accountName, owner_id, realname ".
			 "from account left outer join member on (owner_id=member.id) ".
			 "where type_id=? order by account.id",
			 $type_id);		
	my $count = 0;
	while (my ($id, $accountName, $owner_id, $owner) = $ar->fetchrow_array) {
	    my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';

	    my $ol = 'n/a';
	    if ($owner_id) {
		$ol = qq'<a href="/hal/admin/members/$owner_id">$owner</a>';
	    }
	    
	    my $inr = db->sql("select sum(amount) from accountTransaction where target_account_id=?", $id);		
	    my ($in) = $inr->fetchrow_array;
	    $inr->finish;

	    my $outr = db->sql("select sum(amount) from accountTransaction where source_account_id=?", $id);		
	    my ($out) = $outr->fetchrow_array;
	    $outr->finish;

	    my $saldo = ($in//0)-($out//0);
	    
	    $html .= qq' <tr $class><td><a href="/hal/admin/accounts/$type_id/$id">$id</a></td>'.
		qq'<td>$accountName</td><td>$ol</td><td>$saldo</td></tr>\n';
	}
	$ar->finish;

	$html .= "</table>\n";

	if ($type_id > 1) {
	    $html .= qq'<p><a href="/hal/admin/accounts/$type_id/create">Lav ny konto af denne type</a></p>\n';
	}
    }

    return outputAdminPage('accounts', $title, $html);
}

sub transactionsPage {
    my ($r,$q,$p, $bleh_type_id, $account_id) = @_;

    my $ar = db->sql("select account.id, type_id, accountName, owner_id, realname ".
		     "from account left outer join member on (owner_id=member.id) ".
		     "where account.id=?", $account_id);		
    my ($id, $type_id, $accountName, $owner_id, $owner) = $ar->fetchrow_array;
    $ar->finish;
    return outputGoto("/hal/admin/accounts/$type_id") unless $id;

    my $rest = db->sql("select id, typename from accounttype order by id") 
	or die "Failed to get list of account types";    
    my @types;
    while (my ($id, $typename) = $rest->fetchrow_array) {
	push @types, {
	    href=>"/hal/admin/accounts/$id",
	    title=>$id == $type_id ? "<strong>$typename</strong>" : $typename,
	};
    }
    $rest->finish;
    
    
    my $html = '<p>Tilbage til: '.selector(@types).'</p>';

    $html .= qq'<p>';
    if ($owner_id) {
	$html .= qq'Denne konto er ejet af <a href="/hal/admin/members/$owner_id">$owner</a>';
    } else {
	$html .= "Denne konto er ejet af foreningen.";
    }
    $html .= '</p>';

    my @table;
    my $tx = db->sql("select t.id, t.created, source_account_id, sa.accountName, target_account_id, ta.accountName, amount, comment ".
		     "from accountTransaction t ".
		     "inner join account sa on (t.source_account_id = sa.id) ".
		     "inner join account ta on (t.target_account_id = ta.id) ".
		     "where target_account_id=? or source_account_id=? ".
		     "order by t.id", $id, $id);
    my $sum = 0;
    my $sumIn = 0;
    my $sumOut = 0;
    while (my ($tid, $created, $source_id, $source, $target_id, $target, $amount, $comment) = $tx->fetchrow_array) {
	my $other = $source_id == $id 
	    ? qq'<a href="/hal/admin/accounts/$type_id/$target_id">$target</a>'
	    : qq'<a href="/hal/admin/accounts/$type_id/$source_id">$source</a>';
	my $in = 0;
	my $out = 0;

	if ($source_id == $id) {
	    $out = $amount;
	    $sum -= $amount;
	    $sumOut += $amount;
	} else {
	    $in = $amount;
	    $sum += $amount;
	    $sumIn += $amount;
	}
	push @table, [$tid, $created, $comment, $other, $in, $out, $sum];
    }
    $tx->finish;
    push @table, ["","", "Totaler", "", $sumIn, $sumOut, $sum];

    $html .= "<table><th>ID</th><th>Dato</th><th>Transaktion</th><th>Fra/Til konto</th><th>Ind</th><th>Ud</th><th>Saldo</th>\n";
    my $count = 0;
    for my $r (reverse @table) {
	my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';
	$html .= qq'<tr $class>'.join('', map {"<td>$_</td>"} @$r).qq'</tr>\n';
    }
    $html .= "</table>";
    
    return outputAdminPage('transactions', "Transaktioner for $accountName", $html);
}

sub createAccountPage {
    my ($r,$q,$p, $type_id) = @_;

    my $rest = db->sql("select typename from accounttype where id=?", $type_id) 
	or die "Failed to get account type name for $type_id";    
    my ($typename) = $rest->fetchrow_array;
    $rest->finish;    
    die "Invalid type_id=$type_id" unless $typename;

    my $html = qq'<p>Opretter en konto af typen: $typename</p>';
    my $errors = 0;
    $html .= qq'<form method="post" action="/hal/admin/accounts/$type_id/create">';

    $html .= textInput("Navn", 'Indtast det navn som konten skal have', 'accountname', $p, sub {
	my ($v,$p,$name) = @_;
	if (length($v)<2) {
	    $errors++;
	    return "Konto navnet skal være længere";
	}
    });

    $html .= memberInput('Ejer', 'Vælg ejeren af kontoen, hvis den ikke er ejet af foreningen',
			 'owner', $p);

    $html .= qq'<hr><input type="submit" name="gogogo" value="Opret konto"></form>';

    if ($p->{gogogo}) {
	if ($errors) {
	    $html .= "<p>Fix fejlen og prøv igen.</p>";
	} else {
	    my $owner_id = $p->{"owner-id"} ? $p->{"owner-id"} : undef;

	    db->sql('insert into account (owner_id, type_id, accountName) values (?,?,?)',
		   $owner_id, $type_id, $p->{accountname})
		or die "Failed to store the new account";
	    my $account_id = db->getID('account') or die "Failed to get new account id";
	    l "Created account $account_id type: $type_id: $p->{accountname}";

	    return outputGoto("/hal/admin/accounts/$type_id/$account_id");	    
	}	
    }

    return outputAdminPage('newaccount', "Opretter konto", $html);
}


sub membersPage {
    my ($r,$q,$p) = @_;

    my $html = '';

    $html .= qq'<table><tr><th>ID</th><th>Bruger</th><th>Navn</th><th>email</th><th>Telefon</th><th>Type</th></tr>';

    my $mr = db->sql("select member.id,username,realname,email,phone,memberType ".
		     "from member inner join membertype on (membertype_id=membertype.id) ".
		     "order by realname")
	or die "Failed to fetch member list";
    my $count = 0;
    while (my ($id, $username, $realname, $email, $phone, $memberType) = $mr->fetchrow_array) {
	my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';
	$html .= qq'<tr $class><td><a href="/hal/admin/members/$id">$id</a></td>'.
	    join('', map {
		"<td>".encode_entities($_||'')."</td>"
		 } ($username,$realname,$email,$phone,$memberType)).'</tr>';
    }
    $mr->finish;

    $html.= "</table>";    

    return outputAdminPage('members', "Medlemmer", $html);
}

sub memberPage {
    my ($r,$q,$p,$member_id) = @_;

    my $html = '';

    $html .= '<table style="width: 100%"><tr><td>';

    my @types;
    my $typesRes = db->sql('select id, memberType, monthlyFee, doorAccess from memberType order by id');
    while (my ($id, $memberType, $monthlyFee, $doorAccess) = $typesRes->fetchrow_array) {
	push @types, {
	    key=>$id,
	    name=>"$memberType ($monthlyFee kr/måned) ".($doorAccess ? '- Inkluderer nøgle til lokalerne' : '- Uden nøgle til lokalerne'),
	}
    }
    $typesRes->finish;
    
    my $mr = db->sql("select username,realname,email,phone,smail,memberType_id,dooraccess,adminaccess ".
		     "from member where id=?", $member_id) or die "Failed to fetch member $member_id";
    my ($username, $realname, $email, $phone, $smail, $membertype_id, $doorAccess, $adminAccess)
	= $mr->fetchrow_array;
    $mr->finish;

    $realname //= '';
    $username //= '';
    $phone //= '';
    $smail //= '';

    $p->{membertype} ||= $membertype_id;
    $html .= qq'
<div class="floaty">
<h2>Detaljer</h2>
<p>
<strong>ID:</strong> $username<br>
$realname<br>
$smail<br>
Tlf. $phone
</p>
<h2>Email</h2>
<p>$email</p>
</div>


<form method="post" action="/hal/admin/members/$member_id">
';
    my $errors = 0;
    
    $html .= '<div class="floaty">';
    $html .= radioInput("Medlems type", "", 'membertype', $p, sub {
	my ($v,$p,$name) = @_;
	unless ($v) {
	    $errors++;
	    return "Vælg venligst medlemsskab";
	}
	return "";
    }, @types);
    $html .= "</div>\n";

    if ($p->{gogogo}) {
	$p->{dooraccess} //= 0;
	$p->{adminaccess} //= 0;
    } else {
	$p->{dooraccess} = $doorAccess;
	$p->{adminaccess} = $adminAccess;
    }

    $html .= '<div class="floaty">';
    $html .= "<h2>Privilegier</h2>";
    my $dac = $p->{dooraccess} ? ' checked="1"' : '';
    $html .= qq'<input type="checkbox" name="dooraccess" value="1"$dac>Adgang til at låse døren op.</input><br/>';
    my $aac = $p->{adminaccess} ? ' checked="1"' : '';
    $html .= qq'<input type="checkbox" name="adminaccess" value="1"$aac>Administrator.</input><br/>';
    $html .= qq'<hr><input style="clear: both" type="submit" name="gogogo" value="Gem ændringer">';
    $html .= "</div></form>\n";

    if ($p->{gogogo}) {
	db->sql("update member set dooraccess=?, adminaccess=?, membertype_id=? where id=?",
		$p->{dooraccess}, $p->{adminaccess}, $p->{membertype}, $member_id)
	    or die "Failed to update member: $p->{dooraccess}, $p->{adminaccess}, $p->{membertype}, $member_id";
    }

    my $ar = db->sql("select account.id, accountName, typeName, type_id ".
		     "from account inner join accounttype on (type_id=accounttype.id) ".
		     "where owner_id=? order by accounttype.id",
		     $member_id)
	or die "Failed to look up accounts owned by the user";

    my $table = qq'<h2>Konti</h2><table><tr><th>ID</th><th>Type</th><th>Navn</th><th>Saldo</th></tr>\n';	
    my $count = 0;
    while (my ($account_id, $accountName, $typeName, $type_id) = $ar->fetchrow_array) {
	my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';
	
	my $inr = db->sql("select sum(amount) from accountTransaction where target_account_id=?", $account_id);
	my ($in) = $inr->fetchrow_array;
	$inr->finish;
	
	my $outr = db->sql("select sum(amount) from accountTransaction where source_account_id=?", $account_id);
	my ($out) = $outr->fetchrow_array;
	$outr->finish;
	
	my $saldo = ($in//0)-($out//0);
	    
	$table .= qq' <tr $class><td><a href="/hal/admin/accounts/$type_id/$account_id">$account_id</a></td>'.
	    qq'<td>$typeName</td><td>$accountName</td><td>$saldo</td></tr>\n';	
    }
    $table .= "</table>";
    $ar->finish;
    $html .= "<td></tr></table> <!-- Yes I'm using a table for layout, so sue me! -->";

    if ($count) {
	$html .= $table;
    } else {
	$html .= "<p>Denne bruger har ingen konto</p>";
    }

    return outputAdminPage('member', "Medlemmer", $html);
}

BEGIN {
    ensureAdmin(qr'^/hal/admin');
    addHandler(qr'^/hal/admin/?$', \&indexPage);
    addHandler(qr'^/hal/admin/load/?$', \&loadPage);
    addHandler(qr'^/hal/admin/consolidate/?$', \&consolidatePage);
    addHandler(qr'^/hal/admin/accounts/?$', \&accountsPage);
    addHandler(qr'^/hal/admin/accounts/(\d+)$', \&accountsPage);
    addHandler(qr'^/hal/admin/accounts/(\d+)/(\d+)$', \&transactionsPage);
    addHandler(qr'^/hal/admin/accounts/(\d+)/create$', \&createAccountPage);
    addHandler(qr'^/hal/admin/members/?$', \&membersPage);
    addHandler(qr'^/hal/admin/members/(\d+)?$', \&memberPage);
}

12;
