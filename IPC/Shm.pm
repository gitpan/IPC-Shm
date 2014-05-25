package IPC::Shm;
use warnings;
use strict;
#
# Attribute interface for shared memory variables.
#
# This is the recommended way to put variables in shared memory.
#
# Synopsis:
#
# use IPC::Shm;
# our $VARIABLE : shm;
#
# And then just use it like you would any other variable.
# Scalars, hashes, and arrays are supported.
# Implemented using tie().
#
###############################################################################
# library dependencies

use Attribute::Handlers;
use Carp;
use Digest::SHA1	qw( sha1_base64 );
use IPC::Shm::Simple;
use IPC::Shm::Tied;

our $VERSION = '0.1';


###############################################################################
# argument normalizers

sub _attrtie_normalize_data($) {
	my ( $data ) = @_;

	if ( not defined $data ) {
		$data = [];
	}

	elsif ( ref( $data ) ne 'ARRAY' ) {
		$data = [ $data ];
	}

	return $data;
}

sub _attrtie_normalize_symbol($$) {
	my ( $sym, $type ) = @_;

	return $sym if $sym eq 'LEXICAL';

	$sym = *$sym;

	my $tmp = $type eq 'HASH' ? '%'
		: $type eq 'ARRAY' ? '@'
		: $type eq 'SCALAR' ? '$'
		: '*';

	$sym =~ s/^\*/$tmp/;

	return $sym;
}


###############################################################################
# sanity checks

sub _attrtie_check_ref_sanity($) {
	my ( $ref ) = @_;

	my $rv = ref( $ref )
		or confess "BUG:\$_[2] is not a reference";

	if ( $rv eq 'CODE' ) {
		confess "Subroutines cannot be placed in shared memory";
	}

	if ( $rv eq 'HANDLE' ) {
		confess "Handles cannot be placed in shared memory";
	}

	return $rv if $rv eq 'HASH';
	return $rv if $rv eq 'ARRAY';
	return $rv if $rv eq 'SCALAR';

	confess "Unknown reference type '$rv'";
}


###############################################################################
# segment lookup routines

sub _attrtie_find_lexical($) {
	my ( $ref ) = @_;
	my ( $rv );

	if ( my $aname = $IPC::Shm::LEXICALS{$ref} ) {
		print "reattaching lexical\n";

		my $shmid = $IPC::Shm::ANONVARS{$aname}
			or croak "awol anonvar $aname";

		$rv = IPC::Shm::Simple->shmat( $shmid )
			or croak "shmattach failed: $!";

		return $rv;
	}

	my $aname = sha1_base64( $ref . $$ );

	if ( my $shmid = $IPC::Shm::ANONVARS{$aname} ) {

		$rv = IPC::Shm::Simple->shmat( $shmid )
			or croak "shmattach failed: $!";

		$IPC::Shm::LEXICALS{$ref} = $aname;

		return $rv;
	}

	$rv = IPC::Shm::Simple->create
		or croak "shmcreate failed: $!";

	$IPC::Shm::ANONVARS{$aname} = $rv->shmid;
	$IPC::Shm::LEXICALS{$ref}   = $aname;

	return $rv;
}

sub _attrtie_find_namevar($) {
	my ( $sym ) = @_;
	my ( $rv );

	if    ( $sym eq '%IPC::Shm::NAMEVARS' ) {
		my $ipckey = 0xdeadbeef;
		$rv = IPC::Shm::Simple->bind( $ipckey );
	}

	elsif ( my $shmid = $IPC::Shm::NAMEVARS{$sym} ) {
		$rv = IPC::Shm::Simple->shmat( $shmid );
		# FIXME look for dangling reference
	}

	else {
		$rv = IPC::Shm::Simple->create;
		$IPC::Shm::NAMEVARS{$sym} = $rv->shmid;
	}

	# FIXME error trapping

	return $rv;
}

sub _attrtie_find_simple($$) {
	my ( $sym, $ref ) = @_;

	return $sym eq 'LEXICAL'
		? _attrtie_find_lexical( $ref )
		: _attrtie_find_namevar( $sym );
}


###############################################################################
# shared memory attribute handler

sub UNIVERSAL::shm : ATTR(ANY) {
	my ( $pkg, $sym, $ref, $attr, $data, $phase ) = @_;
	my ( $type );

	print "_do_tie( $pkg, $sym, $ref )\n";

	$data = _attrtie_normalize_data( $data );
	$type = _attrtie_check_ref_sanity( $ref );
	$sym  = _attrtie_normalize_symbol( $sym, $type );

	my $segment = _attrtie_find_simple( $sym, $ref )
		or confess "Unable to find shm store";

	if    ( $type eq 'HASH' ) {
		tie %$ref, 'IPC::Shm::Tied', $segment, @$data;
	}

	elsif ( $type eq 'ARRAY' ) {
		tie @$ref, 'IPC::Shm::Tied', $segment, @$data;
	}

	elsif ( $type eq 'SCALAR' ) {
		tie $$ref, 'IPC::Shm::Tied', $segment, @$data;
	}

	if ( $sym eq '%IPC::Shm::NAMEVARS' ) {
		$IPC::Shm::NAMEVARS{$sym} ||= $segment->shmid;
	}

}


###############################################################################
# shared memory variables used by this package

our %NAMEVARS : shm;
our %ANONVARS : shm;
our %LEXICALS;


###############################################################################
# garbage collection

sub END {

	foreach my $lname ( keys %LEXICALS ) {
		my $aname = $LEXICALS{$lname};
		my $shmid = $ANONVARS{$aname};

		my $share = IPC::Shm::Simple->shmat( $shmid )
			or next;

		$share->decref;

		unless ( $share->nrefs ) {
			delete $ANONVARS{$aname};
			$share->remove;
		}

	}

}


###############################################################################
###############################################################################
1;
