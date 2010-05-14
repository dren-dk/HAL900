#-*-perl-*-
package HAL::Layout;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(htmlPage htmlPageWithMenu);
use strict;
use warnings;
use POSIX;

sub htmlPage($$;$) {
    my ($title, $body, $opt) = @_;
    
    my $headers = '';
    if ($opt) {
	if ($opt->{feed}) {
	    $headers .= qq'\n  <link rel="alternate" type="application/rss+xml" '.
		qq'title="RSS feed" href="$opt->{feed}/feed.rss" />';
	}
    }

    $headers .= qq'<META HTTP-EQUIV="Refresh" CONTENT="30">' if $opt->{autorefresh};
    
    $title .= " @ ".scalar strftime("%a, %d  %b  %Y  %H:%M:%S  %Z", localtime(time));
    
    return qq'<?xml version="1.0" encoding="iso-8859-1"?>
<!DOCTYPE html
        PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
         "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" lang="en-US" xml:lang="en-US">
<head>
  <title>$title</title>$headers
  <style type="text/css">\@import "/hal-static/style.css";</style>
</head><body>
$body
</body></html>';
}

sub htmlPageWithMenu($$$) {
    my ($opt, $items, $content) = @_;
    
    my $menu = '';
    for my $item (@$items) {
	if ($item->{current}) {
	    $opt->{title} ||= $item->{title};
	    $menu .= qq'                    <li><span>$item->{title}</span></li>\n';
	} else {
	    $menu .= qq'                    <li><a href="$item->{link}">$item->{title}</a></li>\n';
	}
    }
    $opt->{title} ||= ''; # No title?

    my $logo = '<img src="/hal/hal-100.png" alt="HAL 900"/>';
    $logo = qq'<a href="/hal/" id="logo" title="Back to the front page">$logo</a>' unless $opt->{dontLinkLogo};
    
    my $feed = '';
    if ($opt->{feed}) {
	my $webPage = qq'\n  <li class="feeditem"><a href="$opt->{feed}/" title="See the newsfeed about this page">Web page</a></li>';
	$webPage = '' if $opt->{noFeedPage};
	$feed = qq'<div id="feeds"><span class="tpop"><img class="intp" src="/hal/news-feeds-100x16.png" width="100" height="16"/><span class="apop">
<ul>$webPage
  <li class="feeditem"><a href="$opt->{feed}/feed.rss" title="Subscribe to the newsfeed using RSS">RSS feed</a></li>
</ul>
        </span></span></div>
';
#  <li class="feeditem"><a href="$opt->{feed}/feed.atom" title="Subscribe to the newsfeed using Atom">Atom feed</a></li>
    }
    my $title;
    my $titleHtml = '';
    my $titleClass = '';
    
    if (ref $opt->{title}) {
	my $t = $opt->{title};
	
	$title = $t->{title};           
	$titleHtml = $t->{html};
	$titleClass = qq' class="$t->{class}"' if $t->{class};	
    } else {
	$titleHtml = qq'<h1 id="title">$opt->{title}</h1>';
	$title = $opt->{title};
    }
    
    my $body = qq'
<div id="head-div">
  <div id="logo-div">$logo</div>
  <div id="title-div"$titleClass>$titleHtml</div>
  <div id="nav-menu"><ul>$menu</ul></div>
  $feed
</div>
<div id="main"><div id="main-content">$content</div></div>
';

    return htmlPage($title, $body, $opt); 
}

1;
