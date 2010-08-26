#-*-perl-*-
package HAL::Page::Books;
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

use Chart::Bars;

use DBI;



sub header_row {
    my $tmp = '';
    foreach (@_) {
	$tmp .= tag($_, "th"); 
    }
    return tag($tmp , "tr");
}

sub row {
    my $tmp = '';
    foreach (@_) {
	$tmp .= tag($_ , "td" );
    }
    return tag ($tmp , "tr");
}

sub tag {
    return "<" . $_[1] . ">" . $_[0] . "</" . $_[1] . ">";
}

sub html_link {
    return '<a href="/hal/admin/books/' . $_[0] . '">' . $_[1] . '</a>';
}


sub outputBookPage($$$;$) {
    my ($cur, $title, $body, $feed) = @_;
    
    my @items = (
	{
	    link=>"/hal/admin/books/repports",
	    name=>'repports',
	    title=>'Rapporter',
	},
	);
    
    my $js;
    my $onload;
    
    for my $i (@items) {
	if ($i->{name} eq $cur) {
	    $i->{current}=1;
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


sub createChart {
    my ($title, $file, @data) = @_;
    my $chart = Chart::Bars->new(600,400);
    my %map = (	'title' => $title);
    $chart->set(%map);
    return "/hal-static/cache/" . $file if  $chart->png("/home/jacob/Desktop/HACK/hal/static/cache/" . $file, \@data);
}


sub accountTable{
    my $acc = shift;
    my $table .='';

    my $acc_info = db->sql("SELECT accountname FROM account WHERE id=?", $acc);
    $acc_info->execute or die $acc_info->errstr;
    my $account_name = $acc_info->fetchrow_array;
    $table .= 'Repport for account ' . $account_name .' number ' . $acc;

    $acc_info->finish;

    $table .= '<table border="1">';



    my $inr = db->sql("SELECT EXTRACT(MONTH FROM accountTransaction.created) AS month, SUM(amount), COUNT(*) FROM accountTransaction WHERE target_account_id=? GROUP BY month ORDER BY month ASC", $acc);
    $inr->execute() or die $inr->errstr;

    my $outr = db->sql("SELECT EXTRACT(MONTH FROM accountTransaction.created) AS month, SUM(amount), COUNT(*) FROM accountTransaction WHERE source_account_id=? GROUP BY month ORDER BY month ASC", $acc);
    $outr->execute() or die $inr->errstr;
    
    my $in_month;
    my $out_month;
    my $in_sum;
    my $out_sum;
    my $in_cnt;
    my $out_cnt;

    my @data = ( [], [], [], []);
    
    $inr->bind_columns(\$in_month, \$in_sum, \$in_cnt);
    $outr->bind_columns(\$out_month, \$out_sum, \$out_cnt);

    $table .= header_row "Måned", "ind", "txi", "ud", "txo", "Balance";

    my $in = 42;
    my $out = 42;
    while ( ($in = $inr->fetchrow_array ) | ($out = $outr->fetchrow_array)) {
	$in_sum = $in ? $in_sum : 0;
	$out_sum = $out ? $out_sum : 0;
	$in_cnt = $in ? $in_cnt : 0;
	$out_cnt = $out ? $out_cnt : 0;
	my $month =$out ? $out_month : $in_month;
	my $balance = ($in_sum)-($out_sum);
	$table .= row $month, $in_sum, $in_cnt,  $out_sum, $out_cnt, $balance;
	push (@{$data[0]}, int($month));
	push (@{$data[1]}, int($in_sum));
	push (@{$data[2]}, int($out_sum));
	push (@{$data[3]}, int($balance));
    } 

    $outr->finish;
    $inr->finish;    

    $table .= '</table>';

    $table .= '<img src="' . createChart($account_name, "tmp.png", @data) .'" />';

    return $table;
}

sub repportPage {
    my ($r,$q,$p) = @_;

    my $html .= '';
    $html .= '<h2>Regnskabs Rapporter</h2>';

    my $accs = db->sql("SELECT DISTINCT id FROM account ORDER BY id");
    $accs->execute() or die $accs->errstr;
    $html .= html_link("repport/" . 42, "Konto nummer " . 42);
    while( my $id = $accs->fetchrow_array) {
    	$html .= tag( html_link("repport/" . $id, "Konto nummer " . $id), "p");
    }
    $accs->finish;
    return outputBookPage('repport', "Regnskab", $html);
}


sub repportDetailsPage {
    my ($r,$q,$p, $account) = @_;
    $account ||= 1;
    my $html .= '';
    $html .= '<h2>Regnskabs Rapport</h2>';
    $html .= accountTable($account);
    return outputBookPage('repport', "Regnskab", $html);

}

BEGIN {
    ensureAdmin(qr'^/hal/admin/books');
    addHandler(qr'^/hal/admin/books$', \&repportPage);
    addHandler(qr'^/hal/admin/books/repports$', \&repportPage);
    addHandler(qr'^/hal/admin/books/repport/(\d+)$', \&repportDetailsPage);
}

12;
