use strict;
use warnings;

use Test::More tests => 16;

our $forkres;

BEGIN { *CORE::GLOBAL::fork = sub { $forkres } }

BEGIN { use_ok( 'Proc::Fork' ); }

{
	local $forkres = 1;
	my $f = parent { ok( 1, 'Parent code executes' ) };
	isa_ok( $f, 'Proc::Fork' );
}

{
	local $forkres = 0;
	my $f = child { ok( 1, 'Child code executes' ) };
	isa_ok( $f, 'Proc::Fork' );
}

{
	my $f = error { ok( 1, 'Error code executes' ) };
	isa_ok( $f, 'Proc::Fork' );
}

{
	my $f = retry { ok( 1, 'Retry code executes' ); 0 };
	isa_ok( $f, 'Proc::Fork' );
}

my $expect_try;
retry {
	++$expect_try;
	is( $_[ 0 ], $expect_try, "Retry attempt $expect_try correctly signalled" );
	return $_[ 0 ] < 5; 
}
error {
	is( $expect_try, 5, "Correctly aborted after 5th attempt" );
};

ok( 1, "I can have a coke now" );
