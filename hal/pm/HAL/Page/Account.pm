#-*-perl-*-
package HAL::Page::Account;
use strict;
use warnings;
use utf8;

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
	    title=>'Skift email',
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
	    title=>'Ret adresse',
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
<h2>Navn og adresse [<a href="/hal/account/details">Ret</a>]</h2>
<p>$realname<br>
$smail<br>
</p>
<p>
Tlf. $phone
</p>

<h2>Email [<a href="/hal/account/email">Ret</a>]</h2>
<p>$email</p>

<h2>Medlems type [<a href="/hal/account/type">Ret</a>]</h2>
<p>$memberType ($monthlyFee kr/måned)</p>

<h2>Privilegier</h2>
<ul>
';
    
    $html .= $doorAccess 
	? '<li>Du kan låse døren til lokalerne op</li>' 
	: $memberDoorAccess 
	   ? '<li>Du kan ikke låse døren til lokalerne op, kontakt <a href="mailto:kasseren@osaa.dk">kasseren@osaa.dk</a></li>'
	   : '<li>Du kan ikke låse døren til lokalerne op, <a href="/hal/account/type">opgrader til betalende medlem</a></li>';
    $html .= $adminAccess ? '<li>Du kan administrere systemet</li>' : '';
    $html .= "</ul>\n";

    return outputAccountPage('index', 'Oversigt', $html);
}

sub logoutPage {
    my ($r,$q,$p) = @_;

    logoutSession();
    return outputGoto('/hal/');
}

BEGIN {
    ensureLogin(qr'^/hal/account');
    addHandler(qr'^/hal/account/?$', \&indexPage);
    addHandler(qr'^/hal/account/logout?$', \&logoutPage);
}

42;
