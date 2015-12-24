use strict; use warnings;

# impossible to beat Test::More into submission when fork() is involved

sub say { print @_, "\n" }

BEGIN {
	say '1..3';
	say 'not ' x $_, 'ok 1 - use Proc::Fork' for !!eval 'use Proc::Fork; 1';
}

# waitpid ensures order of output
child  {                     say 'ok 2 - child code runs'  }
parent { waitpid shift, 0;   say 'ok 3 - parent code runs' }
