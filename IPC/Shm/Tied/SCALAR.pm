package IPC::Shm::Tied::SCALAR;
use warnings;
use strict;

use base 'IPC::Shm::Tied::base';

sub _empty {
	return \'';
}

sub TIESCALAR {
	my ( $class, $store, @args ) = @_;

	return $class->_rebless( $store, @args );
}

sub FETCH {
	my ( $this ) = @_;

	$this->readlock;
	$this->fetch;
	$this->unlock;

	return ${$this->vcache};
}

sub STORE {
	my ( $this, $value ) = @_;

	$this->writelock;
	$this->vcache( \$value );
	$this->flush;
	$this->unlock;

	return $value;
}

sub UNTIE {
	my ( $this ) = @_;
	print "untying scalar shared\n";	
}


1;
