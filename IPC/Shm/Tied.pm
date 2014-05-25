package IPC::Shm::Tied;
use warnings;
use strict;

use IPC::Shm::Tied::HASH;
use IPC::Shm::Tied::ARRAY;
use IPC::Shm::Tied::SCALAR;

sub TIEHASH {
	shift; # discard class we were called as
	return IPC::Shm::Tied::HASH->TIEHASH( @_ );
}

sub TIEARRAY {
	shift; # discard class we were called as
	return IPC::Shm::Tied::ARRAY->TIEARRAY( @_ );
}

sub TIESCALAR {
	shift; # discard class we were called as
	return IPC::Shm::Tied::SCALAR->TIESCALAR( @_ );
}


1;
