#-*-perl-*-
package HAL::Page::Front;
use strict;
use warnings;
use HAL::Pages;
#use HAL::DB;
#use HAL::Session;

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

    return outputFrontPage("index", "Front page", "Test hest");
}

sub notFound {
    my ($r,$q,$p) = @_;

    my $name = 'Dave';    
    # If logged in find first name.

    return outputFrontPage("404", "Not found", 
      "Sorry $name, I can't do that, the page you are looking for is not here.");
}

BEGIN {
    addHandler(qr'^/hal/?$', \&index);
    addHandler(qr'^/', \&notFound, 10000);
}

42;
