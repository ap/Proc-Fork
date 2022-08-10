use 5.006; use strict; use warnings;

package Proc::Fork;

our $VERSION = '0.806';

use Exporter::Tidy (
	default => [ ':all' ],
	wrapper => [ 'run_fork' ],
	blocks  => [ qw( parent child error retry ) ],
);

sub _croak { require Carp; goto &Carp::croak }

my $do_clear = 1;
my ( $parent, $child, $error, $retry );

sub run_fork(&) {
	my $setup = shift;

	my @r = $setup->();
	_croak "Garbage in Proc::Fork setup (semicolon after last block clause?)" if @r;
	$do_clear = 1;

	my $pid;
	my $i;

	{
		$pid = fork;
		last if defined $pid;
		redo if $retry and $retry->( ++$i );
		die "Cannot fork: $!\n" if not $error;
		$error->();
		return;
	}

	$_->( $pid || () ) for ( $pid ? $parent : $child ) || ();

	return;
}

for my $block ( qw( parent child error retry ) ) {
	my $code = q{sub _BLOCK_ (&;@) {
		$parent = $child = $error = $retry = $do_clear = undef if $do_clear;
		_croak "Duplicate _BLOCK_ clause in Proc::Fork setup" if $_BLOCK_;
		$_BLOCK_ = shift if 'CODE' eq ref $_[0];
		_croak "Garbage in Proc::Fork setup (after _BLOCK_ clause)" if @_;
		run_fork {} if not defined wantarray; # backcompat
		();
	}};
	$code =~ s/_BLOCK_/$block/g;
	eval $code;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Proc::Fork - simple, intuitive interface to the fork() system call

=head1 SYNOPSIS

 use Proc::Fork;

 run_fork {
     child {
         # child code goes here.
     }
     parent {
         my $child_pid = shift;
         # parent code goes here.
         waitpid $child_pid, 0;
     }
     retry {
         my $attempts = shift;
         # what to do if fork() fails:
         # return true to try again, false to abort
         return if $attempts > 5;
         sleep 1, return 1;
     }
     error {
         # Error-handling code goes here
         # (fork() failed and the retry block returned false)
     }
 };

=head1 DESCRIPTION

This module provides an intuitive, Perl-ish way to write forking programs by letting you use blocks to illustrate which code section executes in which fork. The code for the parent, child, retry handler and error handler are grouped together in a "fork block". The clauses may appear in any order, but they must be consecutive (without any other statements in between).

All four clauses need not be specified. If the retry clause is omitted, only one fork will be attempted. If the error clause is omitted the program will die with a simple message if it can't retry. If the parent or child clause is omitted, the respective (parent or child) process will start execution after the final clause. So if one or the other only has to do some simple action, you need only specify that one. For example:

 # spawn off a child process to do some simple processing
 run_fork { child {
     exec '/bin/ls', '-l';
     die "Couldn't exec ls: $!\n";
 } };
 # Parent will continue execution from here
 # ...

If the code in any of the clauses does not die or exit, it will continue execution after the fork block.

=head1 INTERFACE

All of the following functions are exported by default:

=head2 run_fork

 run_fork { ... }

Performs the fork operation configured in its block.

=head2 child

 child { ... }

Declares the block that should run in the child process.

=head2 parent

 parent { ... }

Declares the block that should run in the parent process. The child's PID is passed as an argument to the block.

=head2 retry

 retry { ... }

Declares the block that should run in case of an error, ie. if C<fork> returned C<undef>. If the code returns true, another C<fork> is attempted. The number of fork attempts so far is passed as an argument to the block.

This can be used to implement a wait-and-retry logic that may be essential for some applications like daemons.

If a C<retry> clause is not used, no retries will be attempted and a fork failure will immediately lead to the C<error> clause being called.

=head2 error

 error { ... }

Declares the block that should run if there was an error, ie when C<fork> returns C<undef> and the C<retry> clause returns false. The number of forks attempted is passed as an argument to the block.

If an C<error> clause is not used, errors will raise an exception using C<die>.

=head1 EXAMPLES

The distribution includes the following examples as separate files in the F<eg/> directory:

=head2 Simple example with IPC via pipe

F<simple.pl>

=head2 Multi-child example

F<multichild.pl>

=head2 Daemon example

F<daemon.pl>

=head2 Forking socket-based network server example

F<server.pl>

=head1 AUTHOR

Aristotle Pagaltzis <pagaltzis@gmx.de>

Documentation by Eric J. Roode.

=head1 COPYRIGHT AND LICENSE

This documentation is copyright (c) 2002 by Eric J. Roode.

=cut
