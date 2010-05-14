#-*-perl-*-
package HAL::Pages;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(l addHandler callHandler outputGoto outputRaw outputNotFound outputHtml);
use strict;
use warnings;
use Data::Dumper;

sub l {
    push @_, "\n", unless @_[@_-1] =~ /\n$/;
    print STDERR 'HAL ', scalar(localtime), ' ', @_;
}

my @handlers;
sub addHandler($$;$) {
    my ($rx, $handler, $order) = @_;
    
    push @handlers, {
	regexp => qr/$rx/,
	handler=> $handler,
	order  => $order||0,
    };

    @handlers = sort {$a->{order} <=> $b->{order}} @handlers;
}

sub callHandler($$$) {
    my ($r, $q, $p) = @_;

    for my $h (@handlers) {
	if (my @match = $r->uri =~ m/$h->{regexp}/) {
	    return $h->{handler}->($r,$q,$p, @match);
	}
    }

    l "No handler found for: ".$r->uri;

    return Apache2::Const::DECLINED;
}

sub outputGoto($) {
    my $uri = shift;
    
    return {
	type=>'goto',
	goto=>$uri,
    };
}

sub outputNotFound($$$) {
    my ($r, $q, $p) = @_;
    
    return {
	code => Apache2::Const::NOT_FOUND,
	opt=>{title=>'Not found'},
	body=>"<p>Sorry, but I don't have the page you want, try going to the front page.</p>",
	items=>[],              
    };
}

sub outputRaw($$) {
    my ($mime, $content) = @_;
    
    return {
	type=>'raw',
	mime=>$mime,
	content=>$content,
    };
}

sub outputHtml($$) {
    my ($title, $body) = @_;
    
    return outputRaw('text/html', 
qq'<html><head><title>$title</title></head>
<body><h1>$title</h1>$body</body></html>');     
}

42;
