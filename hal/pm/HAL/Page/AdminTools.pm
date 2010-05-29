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

    my $id = $p->{id} || '';
    $id =~ s/\D+//g;
    my $needle = lc($p->{needle} || '');

    return outputRaw('text/xml', '<hits hint="moar!"/>') unless $id or length($needle) > 1;

    my $xml;
    my $writer = new XML::Writer(OUTPUT => \$xml, NEWLINES => 1);

    my $like = "\%$needle\%";
    
    my $res;

    if ($id) {
	$res = db->sql("select id, realname, username, email from member where id=?", $id) 
	    or die "Failed to search member list for id=$id";
    } else {
	$res = db->sql("select id, realname, username, email from member ".
		       "where lower(email) like ? or lower(username) like ? or lower(realname) like ?",
		       $like, $like, $like) 
	    or die "Failed to search member list";
    }

    $writer->startTag('hits', needle=>$needle, id=>$id);
    while (my ($id, $realname, $username, $email) = $res->fetchrow_array) {

	my $aka = (defined $username ? " aka. $username" :'');

	$writer->emptyTag("hit", id=>$id, text=>"$realname$aka &lt;$email&gt;");
    }
    $res->finish;
    $writer->endTag('hits');
    $writer->end();
    
    return outputRaw('text/xml', $xml);
}

BEGIN {
    addHandler(qr'^/hal/admin/tool/dirtybank.xml$', \&dirtyData);
    addHandler(qr'^/hal/admin/tool/search/member$', \&memberSearch);
}

12;
