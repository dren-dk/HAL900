#-*-perl-*-
package HAL::DB;

use strict;
use DBI;
use Carp qw(confess cluck);
use Storable qw(freeze thaw);
use Data::Dumper;
use MIME::Base64;

sub new($) {
        my $class = shift;
        return bless {
                autocommit=>0,
        }, $class;
}

sub setAutoCommit($$) {
        my ($self, $ac) = @_;
        $self->{autocommit} = $ac;              
}


# Re-implementation of connect_cached, needed to support forking after using the database.
my $cachedDbh;
my $cachedPid;
my $cachedLastUse;
sub dbh($) {
    my $self = shift;
    
    if ($cachedDbh and $cachedPid) {
	if ($$ == $cachedPid) {
	    if (time - $cachedLastUse > 10) { # Allow reuse without pinging
		if ($cachedDbh->ping) {
		    $cachedLastUse = time;
		    return $cachedDbh;
		}
	    } else {
		$cachedLastUse = time;
		return $cachedDbh;                              
	    }
	} else {
	    $cachedDbh->{InactiveDestroy} = 1;
	    $cachedPid = $cachedDbh = undef;
	}
    }
    
    $cachedLastUse = time;
    $cachedPid = $$;
    return $cachedDbh = DBI->connect("dbi:Pg:dbname=hal;port=5433",
				     'hal', 'hal900', {
					 AutoCommit => $self->{autocommit},
				     }) or confess "Unable to connect to the database";
}

END {
    if ($cachedDbh and $cachedPid and $$ != $cachedPid) {
	$cachedDbh->{InactiveDestroy} = 1;
	$cachedPid = $cachedDbh = undef;
    }
}

sub sql {
    my $self = shift;
    my $sql = shift;
    
    my $sth = $self->dbh->prepare_cached($sql);
    my $rv = $sth->execute(@_);
    
    return ($sth, $rv) if wantarray;
    
    if ($sql =~ /^select/i) {
	return $sth;
    } else {
	$sth->finish();
	return $rv;
    }
}

1;
