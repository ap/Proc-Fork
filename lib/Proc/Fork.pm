#!/usr/bin/perl

package Proc::Fork;

$VERSION = 0.7; # also change it in the docs and in Fork/Runner.pm

use strict;
use warnings;
use vars '$RUN_CLASS';

$RUN_CLASS ||= 'Proc::Fork::Runner';
eval "require $RUN_CLASS" or die $@;

sub run_fork(&) {
	my ( $setup ) = @_;
	my $runner = $setup->();
	if ( not eval { $runner->isa( $RUN_CLASS ) } ) {
		require Carp;
		Carp::croak( "Syntax error (trailing garbage in block after Proc::Fork setup?)" );
	}
	$runner->run;
	return;
}

my $make_forkblock = sub {
	my ( $config_key ) = shift;
	sub (&;$) {
		my ( $val, $config ) = @_;

		# too many arguments or not a config hash as 2nd argument?
		# then the user has almost certainly forgotten the trailing semicolon
		if ( @_ > 2 or ( @_ == 2 and not eval { $config->isa( $RUN_CLASS ) } ) ) {
			require Carp;
			Carp::croak( "Syntax error (missing semicolon after $config_key clause?)" );
		}

		( $config ||= $RUN_CLASS->new )->set( $config_key, $val );

		# if not called in void context, then we're not the final part of the call
		# chain, so just pass the config up the chain
		defined wantarray ? return $config : $config->run;
	};
};

require Exporter::Tidy;
Exporter::Tidy->import(
	default => [ ':all' ],
	wrapper => [ 'run_fork' ],
	blocks  => [ $RUN_CLASS->blocks ],
	_map    => { map { $_ => $make_forkblock->( $_ ) } $RUN_CLASS->blocks },
);

__PACKAGE__->import( ':blocks' );

1;

__END__

=head1 NAME

Proc::Fork - Simple, intuitive interface to the fork() system call

=head1 VERSION

This documentation describes Proc::Fork version 0.7

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
         # what to do if if fork() fails:
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

=head2 Simple example with IPC via pipe

 use strict;
 use Proc::Fork;

 use IO::Pipe;
 my $p = IO::Pipe->new;

 run_fork {
     parent {
         my $child = shift;
         $p->reader;
         print while <$p>;
         waitpid $child,0;
     }
     child {
         $p->writer;
         print $p "Line 1\n";
         print $p "Line 2\n";
         exit;
     }
     retry {
         if( $_[0] < 5 ) {
             sleep 1;
             return 1;
         }
         return 0;
     }
     error {
         die "That's all folks\n";
     }
 };

=head2 Multi-child example

 use strict;
 use Proc::Fork;
 use IO::Pipe;

 my $num_children = 5;    # How many children we'll create
 my @children;            # Store connections to them
 $SIG{CHLD} = 'IGNORE';   # Don't worry about reaping zombies

 # Spawn off some children
 for my $num ( 1 .. $num_children ) {
     # Create a pipe for parent-child communication
     my $pipe = IO::Pipe->new;

     # Child simply echoes data it receives, until EOF
     run_fork { child {
         $pipe->reader;
         my $data;
         while ( $data = <$pipe> ) {
             chomp $data;
             print STDERR "child $num: [$data]\n";
         }
         exit;
     } };

     # Parent here
     $pipe->writer;
     push @children, $pipe;
 }

 # Send some data to the kids
 for ( 1 .. 20 ) {
     # pick a child at random
     my $num = int rand $num_children;
     my $child = $children[$num];
     print $child "Hey there.\n";
 }

=head2 Daemon example

 use strict;
 use Proc::Fork;
 use POSIX;

 # One-stop shopping: fork, die on error, parent process exits.
 run_fork { parent { exit } };

 # Other daemon initialization activities.
 $SIG{INT} = $SIG{TERM} = $SIG{HUP} = $SIG{PIPE} = \&some_signal_handler;
 POSIX::setsid() or die "Cannot start a new session: $!\n";
 close $_ for *STDIN, *STDOUT, *STDERR;

 # rest of daemon program follows

=head2 Forking socket-based network server example

 use strict;
 use IO::Socket::INET;
 use Proc::Fork;

 $SIG{CHLD} = 'IGNORE';

 my $server = IO::Socket::INET->new(
     LocalPort => 7111,
     Type      => SOCK_STREAM,
     Reuse     => 1,
     Listen    => 10,
 ) or die "Couln't start server: $!\n";

 my $client;
 while ($client = $server->accept) {
     run_fork { child {
         # Service the socket
         sleep(10);
         print $client "Ooga! ", time % 1000, "\n";
         exit; # child exits. Parent loops to accept another connection.
     } }
 }

=head1 EXPORTS

This package exports the following symbols by default.

=over 4

=item * C<run_fork>

=item * C<child>

=item * C<parent>

=item * C<retry>

=item * C<error>

=back

=head1 DEPENDENCIES

L<Carp>, which is part of the Perl distribution, and L<Exporter::Tidy>.

=head1 BUGS AND LIMITATIONS

None currently known, for what that's worth.

Please report any bugs or feature requests to C<bug-proc-fork@rt.cpan.org>, or through the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Proc-Fork>. I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 AUTHOR

Aristotle Pagaltzis, L<mailto:pagaltzis@gmx.de>

Documentation by Eric J. Roode.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2005-2008 by Aristotle Pagaltzis. All rights Reserved.

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself. See L<perlartistic>.

=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

=cut
