#!perl -T

use Test::More;
eval "use Test::Pod 1.14";
plan skip_all => 'Test::Pod 1.14 required for testing POD' if $@;
plan skip_all => 'Set the TEST_POD environment variable to run these tests' if not exists $ENV{TEST_POD};
all_pod_files_ok();

# vim:ft=perl:
