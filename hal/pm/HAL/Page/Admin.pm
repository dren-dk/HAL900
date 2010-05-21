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
	},
	{
	    link=>"/hal/admin/accounts",
	    name=>'accounts',
	    title=>'Accounts',
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
	for my $t (@txn) {
	    my $res = db->sql("select count(*) from bankTransaction where bankDate=? and bankComment=? and amount=? and bankSum=?",
			      $t->{date}, $t->{text}, $t->{amount}, $t->{sum});
	    my ($dup) = $res->fetchrow_array;
	    $res->finish;

	    if ($dup) {
		$msg .= "<tr><td>$t->{date}</td><td>$t->{text}</td><td>$t->{amount}</td><td>Duplet, ignoreret.</td></tr>\n";
	    } else {
		$msg .= "<tr><td>$t->{date}</td><td>$t->{text}</td><td>$t->{amount}</td><td>Ny</td></tr>\n";

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

BEGIN {
    ensureAdmin(qr'^/hal/admin');
    addHandler(qr'^/hal/admin/?$', \&indexPage);
    addHandler(qr'^/hal/admin/load$', \&loadPage);
}

12;
