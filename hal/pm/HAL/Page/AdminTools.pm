#-*-perl-*-
package HAL::Page::AdminTools;
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

use XML::Writer;

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


sub memberSearch {
    my ($r,$q,$p) = @_;

    my $needle = lc($p->{needle} || '');

    return outputRaw('text/xml', '<members hint="moar!"/>') unless length($needle) > 1;

    my $xml;
    my $writer = new XML::Writer(OUTPUT => \$xml, NEWLINES => 1);

    $needle = "\%$needle\%";
    my $res = db->sql("select id, realname, username, email from member ".
		      "where lower(email) like ? or lower(username) like ? or lower(realname) like ?",
		      $needle, $needle, $needle) 
	or die "Failed to search member list";

    $writer->startTag('members');
    while (my ($id, $realname, $username, $email) = $res->fetchrow_array) {
	$writer->emptyTag("member", 
			  id=>$id,
			  realname=>$realname,
			  username=>(defined $username ? $username :''),
			  email=>$email,
	    );
    }
    $res->finish;
    $writer->endTag('members');
    $writer->end();
    
    return outputRaw('text/xml', $xml);
}

BEGIN {
    addHandler(qr'^/hal/admin/tool/dirtybank.xml$', \&dirtyData);
    addHandler(qr'^/hal/admin/tool/search/member$', \&memberSearch);
}

12;
