use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
	module_name         => 'Proc::Fork',
	license             => 'perl',
	dist_author         => 'Aristotle Pagaltzis <pagaltzis@gmx.de>',
	build_requires      => { 'Test::More' => 0 },
	add_to_cleanup      => [ 'Proc-Fork-*' ],
	create_makefile_pl  => 'traditional',
);

$builder->create_build_script();
