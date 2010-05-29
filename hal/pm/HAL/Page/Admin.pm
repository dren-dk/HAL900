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

	    my $saldo = $in//0-$out//0;
	    
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
    my $html = '';
    
    $html .= qq'<form method="post" action="/hal/admin/$type_id/create">';

    $html .= memberInput('Ejer', 'Vælg ejeren af kontoen, hvis den ikke er ejet af foreningen',
			 'owner_id', $p);
    $html .= memberInput('Ejer1', 'Vælg ejeren af kontoen, hvis den ikke er ejet af foreningen1',
			 'owner_id1', $p);

#    $html .= typeAhead('member_id', '', 'member');
#    $html .= typeAhead('hest_member_id', '', 'member');

    $html .= qq'</form>';

    return outputAdminPage('newaccount', "Opretter konto", $html);
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
}

12;
