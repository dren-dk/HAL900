#-*-perl-*-
package HAL::Page::Front;
use strict;
use warnings;
use HAL::Pages;
use HAL::Session;

sub outputFrontPage($$$;$) {
    my ($cur, $title, $body, $feed) = @_;
    
    my @items = (
	{
	    link=>"/hal/",
	    name=>'index',
	    title=>'HAL:900',
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

    return outputFrontPage("index", "Front page", 
			   "<p>Velkommen til HAL:900, OSAAs medlemsdatabase som holder styr på medlemmer, økonomi og adgangskontrol.</p>");
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



BEGIN {
    addHandler(qr'^/hal/?$', \&index);
    addHandler(qr'^/hal/nocookie$', \&noCookie);
    addHandler(qr'^/', \&notFound, 10000);
}

42;
