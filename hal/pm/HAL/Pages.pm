#-*-perl-*-
package HAL::Pages;
require Exporter;
@ISA=qw(Exporter);
@EXPORT = qw(l db dbCommit dbRollback addHandler callHandler outputGoto outputRaw outputNotFound outputHtml textInput areaInput passwdInput2 passwdInput radioInput memberInput setCurrentIP setCurrentUser);
use strict;
use warnings;
use Data::Dumper;
use HAL::DB;
use HTML::Entities;
use HAL::TypeAhead;

my $db;
sub db {
    $db = new HAL::DB unless $db;
    return $db;
}

sub dbCommit {
    $db->dbh->commit if $db;
    $db = undef;
}

sub dbRollback {
    $db->dbh->rollback if $db;
    $db = undef;
}

my $currentUser = '';
my $currentIP = '';
sub setCurrentIP {
    $currentIP = shift;
    $currentUser = '';
}

sub setCurrentUser {
    $currentUser = shift;
}

sub l {
    push @_, "\n", unless @_[@_-1] =~ /\n$/;
    my $id = $currentIP;
    $id = "$id($currentUser)" if $currentUser;
    print STDERR 'HAL ', scalar(localtime),' ', $id,' ' , @_;
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
#	    l "Found handler: $h->{regexp} for ".$r->{uri};
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

sub textInput {
    my ($title, $lead, $name, $p, $validator) = @_;

    my $v = $p->{$name} || '';

    my $error = '';
    if (defined $p->{$name} and $validator) {
	$error = $validator->($v,$p,$name);
	if ($error) {
	    $error = qq'<p class="error">$error</p>';
	}
    }

    my $e = encode_entities($v);
    return qq'
<h4>$title</h4>
<p class="lead">$lead</p>
<input type="text" name="$name" id="$name" size="50" value="$e">
$error
';
}

sub passwdInput {
    my ($title, $lead, $name, $p, $validator) = @_;

    my $v = $p->{$name} || '';

    my $error = '';
    if (defined $p->{$name} and $validator) {
	$error = $validator->($v,$p,$name);
	if ($error) {
	    $error = qq'<p class="error">$error</p>';
	}
    }

    my $e = encode_entities($v);
    return qq'
<h4>$title</h4>
<p class="lead">$lead</p>
<input type="password" name="$name" size="50" value="">
$error
';
}

sub areaInput {
    my ($title, $lead, $name, $p, $validator) = @_;

    my $v = $p->{$name} || '';

    my $error = '';
    if (defined $p->{$name} and $validator) {
	$error = $validator->($v,$p,$name);
	if ($error) {
	    $error = qq'<p class="error">$error</p>';
	}
    }

    my $e = encode_entities($v);
    return qq'
<h4>$title</h4>
<p class="lead">$lead</p>
<textarea name="$name" cols="50" rows="4">
$e
</textarea>
$error
';
}

sub passwdInput2 {
    my ($title, $lead, $name, $p, $validator) = @_;

    my $v = $p->{$name} || '';

    my $error = '';
    if (defined $p->{$name} and $validator) {
	$error = $validator->($v,$p,$name);
	if ($error) {
	    $error = qq'<p class="error">$error</p>';
	}
    }

    my $e = encode_entities($v);
    return qq'
<h4>$title</h4>
<p class="lead">$lead</p>
<input type="password" name="$name" size="20" value=""><input type="password" name="${name}_confirm" size="20" value="">
$error
';
}

sub radioInput {
    my ($title, $lead, $name, $p, $validator, @options) = @_;

    my $v = $p->{$name} || '';

    my $error = '';
    if (defined $p->{"${name}_check"} and $validator) {
	$error = $validator->($v,$p,$name);
	if ($error) {
	    $error = qq'<p class="error">$error</p>';
	}
    }

    my $buttons = join '<br>', map {
	my $checked = $_->{key} eq $v ? ' checked' : '';
	qq'<input type="radio" name="$name" value="$_->{key}"$checked>$_->{name}</input>'
    } @options;

    my $e = encode_entities($v);
    return qq'
<h4>$title</h4>
<p class="lead">$lead</p>
<input type="hidden" name="${name}_check" value="1">
$buttons
$error
';
}

sub memberInput {
    my ($title, $lead, $name, $p, $validator) = @_;

    my $v = $p->{$name} || '';

    my $error = '';
    if (defined $p->{$name} and $validator) {
	$error = $validator->($v,$p,$name);
	if ($error) {
	    $error = qq'<p class="error">$error</p>';
	}
    }

    return qq'
<h4>$title</h4>
<p class="lead">$lead</p>
'.typeAhead($name, $v, 'member').$error;
}



42;
