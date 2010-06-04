#-*-perl-*-
package HAL::DB;

use strict;
use DBI;
use Carp qw(confess cluck);
use Storable qw(freeze thaw);
use Data::Dumper;
use MIME::Base64;
use HAL;

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
    return $cachedDbh = DBI->connect(getDBUrl(),
				     'hal', 'hal900', {
					 AutoCommit => $self->{autocommit},
					 pg_enable_utf8=>1,
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

sub getID {
    my $self = shift;
    my $table = shift;
    $table =~ s/[^a-zA-Z0-9_]//g;

    my $idRes = $self->sql("select currval(pg_get_serial_sequence('$table', 'id'))") or die "Failed to get id from insert into $table";
    my ($id) = $idRes->fetchrow_array;
    $idRes->finish;

    return $id;
}


sub getAccountTypeBalance {
    my ($self, $member_id, $accounttype_id) = @_;

    my $ar = $self->sql("select id from account where owner_id=? and type_id=?",
			$member_id, $accounttype_id);
    my ($account_id) = $ar->fetchrow_array;
    $ar->finish;

    return undef unless $account_id;
    return ($self->getAccountBalance($account_id), $account_id) if wantarray;
    return  $self->getAccountBalance($account_id);
}

sub getAccountBalance {
    my ($self, $account_id) = @_;

    my $inr = $self->sql("select sum(amount) from accountTransaction where target_account_id=?",
		      $account_id);		
    my ($in) = $inr->fetchrow_array;
    $inr->finish;

    my $outr = $self->sql("select sum(amount) from accountTransaction where source_account_id=?", 
		       $account_id);		
    my ($out) = $outr->fetchrow_array;
    $outr->finish;
    
    return ($in//0)-($out//0);
}

1;
