#-*-perl-*-
package HAL::Page::Front;
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

sub outputFrontPage($$$;$) {
    my ($cur, $title, $body, $feed) = @_;
    
    my @items = (
	{
	    link=>"/hal/",
	    name=>'index',
	    title=>'HAL:900',
	},
	{
	    link=>"/hal/new",
	    name=>'new',
	    title=>'Ny bruger',
	},

	);

#	{
#	    link=>"/hal/login",
#	    name=>'login',
#	    title=>'Login',
#	},

    
    for my $i (@items) {
	$i->{current}=1 if $i->{name} eq $cur;
    }
    
    return {
	opt=>{
	    title=>$title,
	    feed=>$feed,
	    dontLinkLogo=>$cur eq 'index',
	    noFeedPage=>$cur eq 'news',
	},
	body=>$body,
	items=>\@items,         
    }
} 

sub index {
    my ($r,$q,$p) = @_;

    my $content = "<p>Velkommen til HAL:900, OSAAs medlemsdatabase som holder styr på medlemmer, økonomi og adgangskontrol.</p>";

    return outputFrontPage("index", "Velkommen", $content);
}

sub notFound {
    my ($r,$q,$p) = @_;

    my $name = 'Dave';    
    # If logged in find first name.

    return outputFrontPage("404", "Not found", 
      "<p>Sorry $name, I can't do that, the page you are looking for is not here.</p>");
}

sub noCookie {
    my ($r,$q,$p) = @_;

    if (getSessionID()) {
	my $session = getSession;
	my $wanted = $session->{wanted} || '/hal/';
	delete $session->{wanted};
	return outputGoto($wanted);
    } 

    return outputFrontPage("nocookie", "No cookie?", 
      "<p>You seem to have turned off cookie support, fix it KTHXBAI.</p>");
}

sub newUser {
    my ($r,$q,$p) = @_;

    my $error = '';
    if ($p->{email}) {

	if (eval { Email::Valid->address(-address => $p->{email},-mxcheck => 1) }) {

	    my $ue = escape_url($p->{email});
	    my $key = sha1_hex($p->{email}.emailSalt());	    
	    
	    my $email = sendmail('register@openspaceaarhus.dk', $p->{email},
				 'Fortsæt Open Space Aarhus registreringen',
"Klik her for at fortsætte registreringen som medlem af Open Space Aarhus:
https://openspaceaarhus.dk/hal/create?email=$ue&key=$key&ex=42

Hvis det ikke er dig der har startet oprettelsen af et medlemsskab hos OSAA,
så kan du enten ignorere denne mail eller sende os en mail på: dave\@osaa.dk
"
		);

	    return outputFrontPage("new", "Opret nyt medlemsskab", 
				   "<p>Tak, vi har nu sendt en mail til ".encode_entities($p->{email}).
				   " med et link til resten af registreringen.</p>");
	} else {
	    $error = 'Mail adressen virker ikke.';	    
	}
    }
   
    my $form = qq'<form method="POST" action="/hal/new">';
    $form .= textInput("Email", "Din email adresse", 'email', $p);
    $form .= qq'<p class="error">$error</p>' if $error;

    $form .= '
<input type="submit" value="Videre">
</form>';

    return outputFrontPage("new", "Opret nyt medlemsskab", $form);
}


BEGIN {
    addHandler(qr'^/hal/?$', \&index);
    addHandler(qr'^/hal/nocookie$', \&noCookie);
    addHandler(qr'^/hal/new$', \&newUser);
    addHandler(qr'^/', \&notFound, 10000);
}

42;
