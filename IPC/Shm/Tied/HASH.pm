package IPC::Shm::Tied::HASH;
use warnings;
use strict;

use base 'IPC::Shm::Tied::base';

sub _empty {
	return {};
}

sub TIEHASH {
	my ( $class, $store, @args ) = @_;

	return $class->_rebless( $store, @args );
}

sub FETCH {
	my ( $this, $key ) = @_;

	$this->readlock;
	$this->fetch;
	$this->unlock;

	return $this->vcache->{$key};
}

sub STORE {
	my ( $this, $key, $value ) = @_;

	$this->writelock;
	$this->fetch;
	$this->vcache->{$key} = $value;
	$this->flush;
	$this->unlock;

	return $value;
}

sub DELETE {
	my ( $this, $key ) = @_;

	$this->writelock;
	$this->fetch;
	delete $this->vcache->{$key};
	$this->flush;
	$this->unlock;

}

sub EXISTS {
	my ( $this, $key ) = @_;

	$this->readlock;
	$this->fetch;
	$this->unlock;

	return exists $this->vcache->{$key};
}

sub FIRSTKEY {
	my ( $this ) = @_;

	$this->readlock;
	$this->fetch;
	$this->unlock;

	foreach my $key ( keys %{$this->vcache} ) {
		return $key;
	}

}

sub NEXTKEY {
	my ( $this, $lastkey ) = @_;
	my $found = 0;

	foreach my $key ( keys %{$this->vcache} ) {
		return $key if $found;	
		$found = 1 if $key eq $lastkey;
	}

}

sub SCALAR {
	my ( $this ) = @_;

	$this->readlock;
	$this->fetch;
	$this->unlock;

	return scalar %{$this->vcache};
}

sub UNTIE {
	my ( $this ) = @_;
	print "untying hash shared\n";
}


1;
