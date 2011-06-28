#-*-perl-*-
package HAL::Page::Admin;
use strict;
use warnings;
use utf8;

use Data::Dumper;
use HTML::Entities;
use Email::Valid;
use Digest::SHA qw(sha1_hex);
use POSIX;

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
	    link=>"/hal/admin/rfid",
	    name=>'rfid',
	    title=>'RFID',
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
	}
    }

    if ($cur eq 'consolidate' or $cur eq 'rain') {
	$js = "$cur.js";
	$onload = "init_$cur();";
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

    my $html = '';
    
    my $sr = db->sql('select count(*), membertype, da from (select m.id, membertype, COALESCE(m.dooraccess, false) as da from member m join membertype t on (m.membertype_id=t.id)) as foo group by membertype, da') or die "Fail!";
    $html = "<h2>Medlems antal efter type</h2><table><tr><th>Medlems type</th><th>Dør-bit</th><th>Antal</th></tr>\n";
    my $i = 0;
    while (my ($count, $type, $access) = $sr->fetchrow_array) {

	my $class = ($i++ & 1) ? 'class="odd"' : 'class="even"';
	$html .= "<tr $class><td>$type</td><td>$access</td><td>$count</td></tr>";
    }
    $html .= "</table>";

    my $fr = db->sql('select membertype, username from member m join membertype t on (m.membertype_id=t.id)') or die "Fail!";
    my %status;
    while (my ($type, $username) = $fr->fetchrow_array) {
	my $s = defined $username ? 'Ok' : 'Mangler brugernavn';
	$status{$type}{$s}++;
    }
    $fr->finish;

    # TODO: Cash state.
    my ($saldot) = (0,0,0);
    $html .= "<h2>Quick economic status</h2><table><tr><th>Account Type</th><th>Total In</th><th>Total Out</th><th>Total Saldo</th></tr>\n";
    for my $accountTypeId (1,2,3) {	
	my $ans = db->sql("select typeName from accountType where id=?", $accountTypeId);
	my ($accountType) = $ans->fetchrow_array;
	$ans->finish;

	my $inr = db->sql("select sum(amount) from accountTransaction t, account a where a.type_id=? and a.id=t.target_account_id", $accountTypeId);		
	my ($in) = $inr->fetchrow_array;
	$inr->finish;
	
	my $outr = db->sql("select sum(amount) from accountTransaction t, account a where a.type_id=? and a.id=t.source_account_id", $accountTypeId);		
	my ($out) = $outr->fetchrow_array;
	$outr->finish;

	$in =~ s/\.00$//;
	$out =~ s/\.00$//;
	
	my $saldo = ($in//0)-($out//0);
	
	$html .= qq'<tr><td>$accountType</td><td>$in</td><td>$out</td><td>$saldo</td></tr>\n';

	$saldot += $saldo;
    }
    $html .= qq'<tr><td>Grand total</td><td></td><td></td><td>$saldot</td></tr>\n';
    $html .= "</table>\n";

    $html .= '<h2>Diverse</h2>';
    $html .= qq'<p><a href="/hal/admin/load">Load nye poster fra Nordea</a></p>';
    $html .= qq'<p><a href="/hal/admin/consolidate">Konsolider nye poster med systemet</a></p>';
    $html .= qq'<p><a href="/hal/admin/rain">Make it rain</a></p>';

    return outputAdminPage('index', 'Admin oversigt', $html);
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

	    my $res = db->sql("select count(*) from bankTransaction where bankDate=? and bankComment=? and amount=?",
			      $t->{date}, $t->{text}, $t->{amount});
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

    my %memberTypes;
    my $tr = db->sql("select id, memberType from membertype");
    while (my ($id, $memberType) = $tr->fetchrow_array) {
	$memberTypes{$id} = $memberType;
    }
    $tr->finish;

    my $html = '<p>Konto type: '.selector(@types).'</p>';
    if ($type_id) {
	$html .= qq'
<table class=\"sortable\">
<tr><th>Konto ID</th><th>Konto navn</th><th>Ejer</th><th>Kommentar</th><th>TX<sub>i<sub></th><th>TX<sub>o<sub></th><th>Saldo</th></tr>
';
	my $ar = db->sql("select account.id, accountName, owner_id, realname, doorAccess, membertype_id ".
			 "from account left outer join member on (owner_id=member.id) ".
			 "where type_id=? order by account.id",
			 $type_id);		
	my $count = 0;
	while (my ($id, $accountName, $owner_id, $owner, $doorAccess, $membertype_id) = $ar->fetchrow_array) {
	    my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';

	    my $ol = 'n/a';
	    my $com = '';
	    if ($owner_id) {

		my $door = $doorAccess ? ' [D]' : '';
		my $type = $memberTypes{$membertype_id};
		$com = "$type$door";

		$ol = qq'<a href="/hal/admin/members/$owner_id">$owner</a>';
	    }
	    
	    my $inr = db->sql("select sum(amount), count(*) from accountTransaction where target_account_id=?", $id);		
	    my ($in, $inc) = $inr->fetchrow_array;
	    $inr->finish;

	    my $outr = db->sql("select sum(amount), count(*) from accountTransaction where source_account_id=?", $id);		
	    my ($out, $outc) = $outr->fetchrow_array;
	    $outr->finish;

	    my $saldo = ($in//0)-($out//0);
	    
	    $html .= qq' <tr $class><td><a href="/hal/admin/accounts/$type_id/$id">$id</a></td>'.
		qq'<td>$accountName</td><td>$ol</td><td>$com</td><td>$inc</td><td>$outc</td><td>$saldo</td></tr>\n';
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
    my ($r,$q,$p, $bleh_type_id, $account_id, $format) = @_;

    $format ||= 'all';
    my $summary = $format =~ /month/ ? 1 : 0;
    my $csv = $format =~ /csv/ ? 1 : 0;

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

    $html .= qq'- <a href="/hal/admin/accounts/$type_id/$id/$format.csv">Export as TSV</a>';

    if ($summary) {
	$html .= qq'- <a href="/hal/admin/accounts/$type_id/$id">Vis alle transaktioner</a>';
    } else {
	$html .= qq'- <a href="/hal/admin/accounts/$type_id/$id/month">Vis sum for hver måned</a>';
    }
    $html .= '</p>';

    my @table;
    my $tx = db->sql("select t.id, date_part('epoch', t.created), source_account_id, sa.accountName, target_account_id, ta.accountName, amount, comment ".
		     "from accountTransaction t ".
		     "inner join account sa on (t.source_account_id = sa.id) ".
		     "inner join account ta on (t.target_account_id = ta.id) ".
		     "where target_account_id=? or source_account_id=? ".
		     "order by t.id", $id, $id);
    my $sum = 0;
    my $sumIn = 0;
    my $sumOut = 0;
    my %month;
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
	push @table, [$tid, strftime("%Y-%m-%d %H:%M", localtime($created)), $comment, $other, $in, $out, $sum];
	
	my $m = strftime("%Y-%m", localtime($created));
	$month{$m}{tx}++;
	$month{$m}{in} += $in;
	$month{$m}{out} += $out;
	$month{$m}{delta} += $in-$out;
	$month{$m}{saldo} = $sum;
    }
    $tx->finish;
    push @table, ["","", "Totaler", "", $sumIn, $sumOut, $sum];

    if ($summary) {

	if ($csv) {
	    my $content = "";
	    for my $m (sort keys %month) {
		$month{$m}{m} = $m;
		$content .= join("\t", map {$month{$m}{$_}} qw(m tx in out delta saldo))."\n";
	    }	    
	    return outputRaw('text/tab-separated-values', $content, "hal-summary.$id.tsv");

	} else {
	    $html .= "<table><th>Måned</th><th>Transaktioner</th><th>Ind</th><th>Ud</th><th>Sum</th><th>Saldo</th>\n";
	    my $count = 0;
	    for my $m (sort keys %month) {
		$month{$m}{m} = $m;
		my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';
		$html .= qq'<tr $class>'.join('', map {"<td>$month{$m}{$_}</td>"} qw(m tx in out delta saldo)).qq'</tr>\n';
	    }
	    $html .= "</table>";
	}

    } else {

	if ($csv) {
	    my $content = "";
	    for my $line (@table) {
		$content .= join "\t", @$line;
		$content .= "\n";
	    }	    
	    return outputRaw('text/tab-separated-values', $content, "hal-transactions.$id.tsv");

	} else {
	    $html .= "<table><th>ID</th><th>Dato</th><th>Transaktion</th><th>Fra/Til konto</th><th>Ind</th><th>Ud</th><th>Saldo</th>\n";
	    my $count = 0;
	    for my $r (reverse @table) {
		my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';
		$html .= qq'<tr $class>'.join('', map {"<td>$_</td>"} @$r).qq'</tr>\n';
	    }
	    $html .= "</table>";
	}
    }
    
    return outputAdminPage('transactions', 
			   $summary ? "Månedlig sum for $accountName" : "Transaktioner for $accountName",
			   $html);
}

sub transactionsExport {
    my ($r,$q,$p, $bleh_type_id, $account_id) = @_;

    my $ar = db->sql("select account.id, type_id, accountName, owner_id, realname ".
		     "from account left outer join member on (owner_id=member.id) ".
		     "where account.id=?", $account_id);		
    my ($id, $type_id, $accountName, $owner_id, $owner) = $ar->fetchrow_array;
    $ar->finish;
    return outputGoto("/hal/admin/accounts/$type_id") unless $id;

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
	my $other;
	my $otherId;
	if ($source_id == $id) {
	    $other = $target;
	    $otherId = $target_id;
	} else {
	    $other = $source;
	    $otherId = $source_id;
	}
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
	push @table, [$tid, $created, $comment, $other, $otherId, $in, $out, $sum];
    }
    $tx->finish;

    my $content = "";
    for my $line (@table) {
	$content .= join "\t", @$line;
	$content .= "\n";
    }
    
    return outputRaw('text/tab-separated-values', $content, "hal-transactions.$id.tsv");
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

    $html .= qq'<table class="sortable"><tr><th>ID</th><th>Bruger</th><th>Navn</th><th>email</th><th>Telefon</th><th>Type</th></tr>';

    my $mr = db->sql("select member.id,username,realname,email,phone,memberType, member.doorAccess ".
		     "from member inner join membertype on (membertype_id=membertype.id) ".
		     "order by realname")
	or die "Failed to fetch member list";
    my $count = 0;
    while (my ($id, $username, $realname, $email, $phone, $memberType, $doorAccess) = $mr->fetchrow_array) {

	$memberType .= " [D]" if $doorAccess;
	$memberType .= " [U]" unless defined $username;

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
';

    my $rfids = '';
    my $rr = db->sql("select id, rfid, pin, lost from rfid where owner_id=?", $member_id)
	or die "Failed to fetch list of RFIDs for user";
    while (my ($id, $rfid, $pin, $lost) = $rr->fetchrow_array) {

	if ($lost) {
	    $rfids .= qq'<p><a href="/hal/admin/rfid/$id">$rfid</a> [Lost]</p>';

	} elsif ($pin) {
	    $rfids .= qq'<p><a href="/hal/admin/rfid/$id">$rfid</a> [OK]</p>';

	} else {
	    $rfids .= qq'<p><a href="/hal/admin/rfid/$id">$rfid</a> [no pin]</p>';	    
	}
    }
    $rr->finish;


    $html .= qq'
<div class="floaty">
<h2>RFID</h2>
$rfids
<p><a href="/hal/admin/members/$member_id/addrfid">Tilføj RFID</a></p>
</div>
';


    $html .= qq'<form method="post" action="/hal/admin/members/$member_id">';
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

sub addRFIDPage {
    my ($r,$q,$p,$member_id) = @_;

    my $html = '';
    
    $html .= qq'<form method="post" action="/hal/admin/members/$member_id/addrfid">';

    $html .= encode_hidden({
	 fromrfid=>$p->{fromrfid} ? 1 : 0,
    });
    
    my $errors = 0;
    $html .= textInput("RFID",
		       "Indtast RFID værdien eller brug USB RFID læseren.",
		       'rfid', $p, sub {
	my ($v,$p,$name) = @_;
	if ($v !~ /^\d{5,10}$/) {
	    $errors ++;
	    return "Æh, hvad? Det ligner ikke et gyldigt RFID";	    
	}
	
	my $res = db->sql("select m.id, realname from rfid r inner join member m on (r.owner_id=m.id) where rfid = ?", $v);
	my ($owner_id, $owner_name) = $res->fetchrow_array;
	$res->finish;
	
	if ($owner_id) {
	    $errors++;
	    return qq'Dette RFID er allerede i brug af <a href="/hal/admin/members/$owner_id">$owner_name</a>';
	}
	return '';
    });
	
    $html .= qq'<hr><input style="clear: both" type="submit" name="gogogo" value="Tilføj RFID">';
    $html .= qq'</form>';

    $html .= qq'
<script>
document.getElementById("rfid").focus();
</script>
';
    if ($p->{rfid} and !$errors) {
	db->sql("insert into rfid (owner_id, rfid) values (?,?)",
		$member_id, $p->{rfid})
	    or die "Failed to insert new rfid for $member_id, $p->{rfid}";
	return outputGoto("/hal/admin/rfid") if $p->{fromrfid};
	return outputGoto("/hal/admin/members/$member_id");
    }

    return outputAdminPage('member', "Tilføj RFID", $html);
}

sub rfidDetailsPage {
    my ($r,$q,$p,$rfid_id) = @_;

    if ($p->{lost}) {
	db->sql("update rfid set lost=true where id=?", $rfid_id) or die "Failed to mark rfid as lost";
    }
    if ($p->{found}) {
	db->sql("update rfid set lost=false where id=?", $rfid_id) or die "Failed to mark rfid as found";
    }

    my $res = db->sql("select m.id, realname, rfid, pin, lost ".
		      "from rfid r inner join member m on (r.owner_id=m.id) ".
		      "where r.id = ?", $rfid_id) or die "failed to look up rfid";
    my ($owner_id, $owner_name, $rfid, $pin, $lost) = $res->fetchrow_array;
    $res->finish;
    return outputGoto("/hal/admin/rfid") unless $rfid;

    my $html = '';

    $html .= qq'<p>Detaljer for RFID #$rfid:</p>';
    $html .= "<ul>";
    $html .= qq'<li>Ejer: <a href="/hal/admin/members/$owner_id">$owner_name</a></li>';
    if ($pin) {
	$html .= '<li>PIN: OK</li>';
    } else {
	$html .= '<li>PIN: Mangler</li>';
    }
    if ($lost) {
	$html .= qq'<li>Markeret som tabt. <a href="/hal/admin/rfid/$rfid_id?found=1">Marker som fundet</a></li>';
    } else {
	$html .= qq'<li>Ikke markeret som tabt. <a href="/hal/admin/rfid/$rfid_id?lost=1">Marker som tabt</a></li>';
    }
        

    return outputAdminPage('rfiddetails', "RFID detaljer", $html);
}

sub rfidPage {
    my ($r,$q,$p) = @_;

    my $html .= '';

    $html .= '<h2>Brugere som mangler RFID nøgler</h2>';
    $html .= qq'<table class="sortable"><tr><th>ID</th><th>Tilføj</th><th>Bruger</th><th>Navn</th><th>email</th><th>Telefon</th><th>Type</th></tr>';

    my $mr = db->sql("select member.id,username,realname,email,phone,memberType ".
		     "from member inner join membertype on (membertype_id=membertype.id) ".
		     "and member.doorAccess ".
		     "and not member.id in (select owner_id from rfid r where not r.lost) ".
		     "order by realname")
	or die "Failed to fetch member list";
    my $count = 0;
    while (my ($id, $username, $realname, $email, $phone, $memberType) = $mr->fetchrow_array) {
	my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';
	$html .= qq'<tr $class><td><a href="/hal/admin/members/$id">$id</a></td>'.
	    qq'<td><a href="/hal/admin/members/$id/addrfid?fromrfid=1">Ny RFID</a></td>'.
	    join('', map {
		"<td>".encode_entities($_||'')."</td>"
		 } ($username,$realname,$email,$phone,$memberType)).'</tr>';
    }
    $mr->finish;
    $html.= "</table>";    
    
    if ($count == 0) {
	$html = "<p>Alle brugere med dør-bit har en RFID nøgle.</p>";
    }

    $html .= '<h2>Eksisterende RFID nøgler</h2>';

    $html .= qq'<table class="sortable"><tr><th>Ejer</th><th>RFID</th><th>Status</th></tr>\n';	
    my $rr = db->sql("select m.id, realname, r.id, rfid, pin, lost ".
		      "from rfid r inner join member m on (r.owner_id=m.id) ".
		      "order by r.id") or die "failed to look up rfids";
    $count = 0;
    while (my ($owner_id, $owner_name, $rfid_id, $rfid, $pin, $lost) = $rr->fetchrow_array) {
	my $class = ($count++ & 1) ? 'class="odd"' : 'class="even"';

	my $status = $pin ? 'Ok' : $lost ? 'Tabt' : 'Mangler PIN';
	$html .= qq'<tr><td><a href="/hal/admin/members/$owner_id">$owner_name</a></td>'.
	    qq'<td><a href="/hal/admin/rfid/$rfid_id">$rfid</a></td><td>$status</td></tr>\n';
    }
    $rr->finish;
    $html.= "</table>";    

    return outputAdminPage('rfid', "RFID", $html);
}

sub rainPage {
    my ($r,$q,$p) = @_;

    my $amount = $p->{amount} || '';
    $amount = 0 unless $amount =~ /^-?\d+(\.\d+)?$/;
    
    my $comment = $p->{comment};
    $comment =~ s/[^a-zA-Z0-9.,æøåÆØÅ()\/ -]//g;

    my $source_account = $p->{source_account};
    my $target_account = $p->{target_account};

    l "$amount and $source_account and $target_account ".Dumper $p;
    if ($p->{rain} and $amount and $source_account and $target_account) {

	if ($source_account < 0) {
	    my $dude_id = -$source_account;
	    my $ar = db->sql("select id from account where owner_id=? and type_id=2", $dude_id);
	    ($source_account) = $ar->fetchrow_array;
	    $ar->finish;
		
	    unless ($source_account) {
		my $dr = db->sql("select realname from member where id=?", $dude_id);
		my ($name) = $dr->fetchrow_array or die "Invalid member id: $dude_id";
		$dr->finish;

		db->sql('insert into account (owner_id, type_id, accountName) values (?,2,?)',
			$dude_id, $name) or die "Failed to store the new account";
		$source_account = db->getID('account') or die "Failed to get new account id";
		l "Created account $source_account for $dude_id type: 2";
	    }
	}

	my @accounts = ($source_account, $target_account);
	if ($amount < 0) {
	    $amount *= -1;
	    @accounts = reverse @accounts;
	}
	
	db->sql('insert into accountTransaction (source_account_id, target_account_id, amount, comment) values (?, ?, ?, ?)',
		@accounts, $amount, $comment
	    ) or die "Failed to insert transaction ".join(',', @accounts, $amount, $comment);


	my $ar = db->sql("select type_id from account where id=?", $source_account);
	my ($type_id) = $ar->fetchrow_array;
	$ar->finish;

	return outputGoto("/hal/admin/accounts/$type_id/$source_account");
    }


    my $load;
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

    
    my $html = qq'
<p>Udfyld denne formular for at betale et medlem penge fra en konto.</p>
<form method="post" action="/hal/admin/rain">

<table id="rain">
<tr><th>Kommentar</th><td><input type="text" size="50" name="comment" value="$comment"></td></tr>
<tr><th>Beløb</th><td><input type="text" size="50" name="amount" value="$amount"></td></tr>
';

    $html .= '<tr><th>Medlem</th><td>';
    $html .= qq'<select name="source_account" id="source_account">\n';
    $html .= qq'  <option value="0">Unknown</option>\n';
    $html .= qq'</select></td></tr>\n';

    $html .= '<tr><th>Konto</th><td>';
    $html .= qq'<select name="target_account" id="target_account">\n';
    $html .= qq'  <option value="0">Unknown</option>\n';
    $html .= qq'</select></td></tr>\n';

    $html .= qq'
</table>
<input type="submit" name="rain" value="Make it rain!">
</form>

<script type="text/javascript">
$load
</script>
';
    
    return outputAdminPage('rain', 'Overfør penge', $html);
}

BEGIN {
    ensureAdmin(qr'^/hal/admin');
    addHandler(qr'^/hal/admin/?$', \&indexPage);
    addHandler(qr'^/hal/admin/load/?$', \&loadPage);
    addHandler(qr'^/hal/admin/consolidate/?$', \&consolidatePage);
    addHandler(qr'^/hal/admin/rain/?$', \&rainPage);
    addHandler(qr'^/hal/admin/accounts/?$', \&accountsPage);
    addHandler(qr'^/hal/admin/accounts/(\d+)$', \&accountsPage);
#    addHandler(qr'^/hal/admin/accounts/(\d+)/(\d+)/csv$', \&transactionsExport);
    addHandler(qr'^/hal/admin/accounts/(\d+)/(\d+)/((month|all)(\.csv)?)$', \&transactionsPage);
    addHandler(qr'^/hal/admin/accounts/(\d+)/(\d+)$', \&transactionsPage);
    addHandler(qr'^/hal/admin/accounts/(\d+)/create$', \&createAccountPage);
    addHandler(qr'^/hal/admin/members/?$', \&membersPage);
    addHandler(qr'^/hal/admin/members/(\d+)?$', \&memberPage);
    addHandler(qr'^/hal/admin/members/(\d+)/addrfid$', \&addRFIDPage);
    addHandler(qr'^/hal/admin/rfid$', \&rfidPage);
    addHandler(qr'^/hal/admin/rfid/(\d+)$', \&rfidDetailsPage);
}

12;
