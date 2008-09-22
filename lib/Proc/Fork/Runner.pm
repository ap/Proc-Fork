#!/usr/bin/perl

package Proc::Fork::Runner;

$VERSION = 0.71;

use strict;
use warnings;

sub new {
	my $self = bless {}, shift;
	@{ $self }{ $self->blocks } = ();
	return $self;
}

sub blocks { qw( parent child error retry ) }

sub set {
	my $self = shift;
	my ( $name, $callback ) = @_;

	if ( not exists $self->{ $name } ) {
		require Carp;
		Carp::croak( "Attempt to set invalid ${\ref $self} attribute '$name'" );
	}

	if ( 'CODE' ne ref $callback ) {
		require Carp;
		Carp::croak( "Attempt to set ${\ref $self} attribute to value that is not a CODE reference" );
	}

	$self->{ $name } = $callback;
	return $self;
}

sub run {
	my $self = shift;

	my ( $p, $c, $e, $r ) = @{ $self }{ $self->blocks };

	my $pid;

	{
		my $retry;

		do {
			$pid = fork;
		} while ( not defined $pid ) and ( $r and $r->( ++$retry ) );
	}

	if    ( not defined $pid ) { $e ? $e->()       : die "Cannot fork: $!\n" }
	elsif ( $pid )             { $p ? $p->( $pid ) : 0 }
	else                       { $c ? $c->()       : 0 }

	return;
}

1;
