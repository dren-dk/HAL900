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

use DBI;

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

sub cell {
    return '<td>' . shift() . '</td>';
}

sub accountTable{
    my $acc = shift;
    my $table .='';
    $table .= 'Repport for account number ' . $acc;
    $table .= '<table>';
    $table .= '<tr><th>Ind</th><th>Ud</th><th>Balance</th></tr>';

    my $month;
    my $in_sum;
    my $out_sum;

    my $inr = db->sql("SELECT EXTRACT(MONTH FROM accountTransaction.created) AS month, SUM(amount) FROM accountTransaction WHERE target_account_id=? GROUP BY month ", $acc);
    $inr->execute();

    my $outr = db->sql("SELECT EXTRACT(MONTH FROM accountTransaction.created) AS month, SUM(amount) FROM accountTransaction WHERE source_account_id=? GROUP BY month ", $acc);
    $outr->execute();
    
        
    $inr->bind_columns(\$month, \$in_sum);
    $outr->bind_col(2, \$out_sum);
    while (my $in = $inr->fetchrow_array) {
	my $out = $outr->fetchrow_array;
	$table .= "<tr>\n";
	$table .= cell($month);
	$table .= cell($in_sum);
	$table .= cell($out_sum);
	$table .= cell(($in_sum//0)-($out_sum//0));
	$table .= "</tr>\n";
    }
    

    $table .= '</table>';
    return $table;
}

sub repportPage {
    my ($r,$q,$p) = @_;

    my $html .= '';

    my $id =1;
    $html .= '<h2>Regnskabs Rapporter</h2>';

    $html .= accountTable(1);

    return outputBookPage('repport', "Regnskab", $html);
}



BEGIN {
    ensureAdmin(qr'^/hal/admin/books');
    addHandler(qr'^/hal/admin/books$', \&repportPage);
    addHandler(qr'^/hal/admin/books/repports$', \&repportPage);
}

12;
