#!perl

use Sub::Defer;

my $deferred;

BEGIN {
    $deferred = defer_sub 'main::mydeferred_sub' => sub {
        my $counter = 0;
        sub { $counter++ };
    };
}

print "1..2\n";

print "ok 1 - sub defer first called\n"  if mydeferred_sub() == 0;
print "ok 2 - sub defer second called\n" if mydeferred_sub() == 1;

