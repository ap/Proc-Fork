#!perl -T
use strict;
use warnings;

# impossible to beat Test::More into submission when fork()'s involved

sub say { print @_, "\n" }

BEGIN { say '1..3'; }

BEGIN { eval 'use Proc::Fork'; if( $@ ) { say 'not ok 1 - use Proc::Fork'; exit } say 'ok 1 - use Proc::Fork' }

# parent uses waitpid to ensure order of output
child  {                   say 'ok 2 - child code runs'  }
parent { waitpid shift, 0; say 'ok 3 - parent code runs' }

# vim:ft=perl:
