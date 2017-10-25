#!./perl

print "1..1\n";

BEGIN {
    sub mysub { return $ENV{'should-not-be-defined'} ? 42 : 44 }
}

print qq[ok 1 - function call\n] if mysub() == 44;

1;
