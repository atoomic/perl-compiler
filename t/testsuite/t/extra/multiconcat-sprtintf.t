#!/bin/env perl

print "1..1\n";

sub f { 42 }
my @a = (1..4);

# S_sprintf_is_multiconcatable is going to be true in this case
my $s = sprintf "a=%s f=%s", $a[0], scalar(f());

print qq[ok 1\n] if $s eq 'a=1 f=42';
