package IPC::Shm::Tied::base;
use warnings;
use strict;

use base 'IPC::Shm::Simple';

use Carp;
use Data::Dumper;
use Storable qw( freeze thaw );


###############################################################################
# value cache, for the unserialized state

sub _empty {
	croak "Abstract _empty() invocation";
}

sub vcache {
	my $this = shift;

	if ( my $create = shift ) {
		return $this->{vcache} = $create;
	}

	unless ( defined $this->{vcache} ) {
		$this->{vcache} = $this->_empty;
	}

	return $this->{vcache};
}


###############################################################################
# serialize and deserialize routines

# reads from scache, writes to vcache
# called by IPC::Shm::Simple::fetch
sub _fresh {
	my ( $this ) = @_;

	my $scache = $this->scache;
	my $serial = $this->serial;
	print "deserializing $serial\n";
	# FIXME: the thaw() call should be inside an eval
	$this->vcache( $$scache ? thaw( $$scache ) : $this->_empty );
	print Dumper( $this->vcache ), "\n";

}

# reads from vcache, calls store
sub flush {
	my ( $this ) = @_;

	print "serializing ", $this->serial + 1, "\n";
	print Dumper( $this->vcache ), "\n";

	$this->store( freeze( $this->vcache ) );
	
}


###############################################################################
# common methods

sub _rebless {
	my ( $class, $store, @args ) = @_;

	my $this = bless $store, $class;

	$this->incref;

	return $this;
}

sub DESTROY {
	my ( $this ) = @_;

	$this->decref;
	$this->SUPER::DESTROY;

}

sub CLEAR {
	my ( $this ) = @_;

	$this->writelock;
	$this->vcache( $this->_empty );
	$this->flush;
	$this->unlock;

}


###############################################################################
###############################################################################
1;
