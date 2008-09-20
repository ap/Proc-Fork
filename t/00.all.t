#!perl -T
use strict;
use warnings;

use Test::More tests => 13;

our $forkres;

BEGIN { *CORE::GLOBAL::fork = sub { $forkres } }

BEGIN { use_ok( 'Proc::Fork' ); }

# basic functionality
{ local $forkres = 1; parent { ok( 1, 'parent code executes' )    };          }
{ local $forkres = 0; child  { ok( 1, 'child code executes'  )    };          }
{                     error  { ok( 1, 'error code executes'  )    };          }
{                     retry  { ok( 1, 'retry code executes'  ); 0 } error {}; }

# error catching attempts
eval { parent {} "oops" };
like( $@, qr/^Syntax error \(missing semicolon after \w+ clause\?\)/, 'syntax error catcher fired' );

# test retry logic
my $expect_try;
retry {
	++$expect_try;
	is( $_[ 0 ], $expect_try, "retry attempt $expect_try signalled" );
	return $_[ 0 ] < 5; 
}
error {
	is( $expect_try, 5, 'abort after 5th attempt' );
};

ok( 1, 'I can have a coke now' );

# vim:ft=perl:
