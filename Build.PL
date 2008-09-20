use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Proc::Fork',
    license             => 'perl',
    dist_author         => 'Aristotle Pagaltzis <pagaltzis@gmx.de>',
    dist_version_from   => 'lib/Proc/Fork.pm',
    requires => { },
	build_requires => {
		'Test::More'          => 0,
		'Test::Pod'           => 0,
		'Test::Pod::Coverage' => 0,
	},
    add_to_cleanup      => [ 'Proc-Fork-*' ],
	create_makefile_pl => 'traditional',
);

$builder->create_build_script();
