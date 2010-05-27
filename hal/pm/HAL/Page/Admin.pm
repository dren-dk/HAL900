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

sub outputAdminPage($$$;$) {
    my ($cur, $title, $body, $feed) = @_;
    
    my @items = (
	{
	    link=>"/hal/admin/",
	    name=>'index',
	    title=>'Hoved konti',
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
	    title=>'Accounts',
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

    my $msg = '<p class="lead">Vælg den csv fil Nordeas Konto-kig exporterede.</p>';

    if ($p->{gogo}) {
	my $f = $q->upload('uploadfile');
	my $data = join('', <$f>);
	utf8::upgrade($data);

	l "Upgraded:\n$data\n";
	
	db->sql('insert into bankBatch (rawCsv) values (?)', $data) or die "Failed to store the csv: $data";
	my $batchID = db->getID('bankBatch');

	l "Got file: $data\n";

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

sub xmlElement {
    my ($name, $attr) = @_;
    return "<$name ".join(" ", map {qq'$_="'.encode_entities($attr->{$_}).'"'} sort keys %$attr)."/>";
}

sub dirtyData {
    my ($r,$q,$p) = @_;

    my $res = db->sql("select id,bankDate, bankComment, amount, userComment from bankTransaction where transaction_id is null order by id") 
	or die "Failed to get unconsolidated transactions";

    my $xml = '<dirty>
';
    while (my ($id, $bankDate, $bankComment, $amount, $userComment) = $res->fetchrow_array) {
	$xml .= " ".xmlElement('txn', {
	    id=>$id,
	    bankDate => $bankDate,
	    bankComment => $bankComment,
	    amount => $amount,
	    userComment => $userComment,
	})."\n";
    }
    $res->finish;
    $xml .= "</dirty>
";
    
    return outputRaw('text/xml', $xml);
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


    my $res = db->sql("select id,bankDate, bankComment, amount, userComment from bankTransaction where transaction_id is null order by id") 
	or die "Failed to get unconsolidated transactions";
    my $html = '

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
	my $uc = qq'<input id="comment_$id" type="text" size="30" value="$ev"/>';
	my $sc = qq'<select id="type_$id" onchange="changetype($id)">\n';
	$sc .= qq'  <option value="0">Unknown</option>\n';
	for my $type (@types) {
	    $sc .= qq'  <option value="$type->{id}">$type->{name}</option>\n';
	}
	$sc .= "</select>\n";

	$sc .= qq'<select id="account_$id">\n';
	$sc .= qq'  <option value="0">Unknown</option>\n';
	$sc .= "</select>\n";
	$html .= qq'<tr $class><td>$bankDate</td><td>$bankComment</td><td class="numeric">$amount</td><td>$sc</td><td>$uc</td></tr>';
    }
    $res->finish;
        
    $html .= '
</table>

<br/>
<input type="submit" value="Gem alt"/>

</form>
';
    return outputAdminPage('consolidate', 'Konsolider poster', $html);
}

BEGIN {
    ensureAdmin(qr'^/hal/admin');
    addHandler(qr'^/hal/admin/?$', \&indexPage);
    addHandler(qr'^/hal/admin/load/?$', \&loadPage);
    addHandler(qr'^/hal/admin/consolidate/?$', \&consolidatePage);
    addHandler(qr'^/hal/admin/consolidate/dirty$', \&dirtyData);
}

12;
