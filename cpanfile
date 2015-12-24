requires 'perl', '5.006';
requires 'strict';
requires 'warnings';
requires 'Carp';

requires 'Exporter::Tidy';

on test => sub {
	requires 'Test::More';
	requires 'vars';
};

# vim: ft=perl
