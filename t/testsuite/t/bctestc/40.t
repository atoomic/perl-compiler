#!/bin/env perl

our ( $a, $b, $c );

$a = "\x{3c3}foo.bar";    # \x{3c3} == GREEK SMALL LETTER SIGMA.
$b = "\x{3a3}FOO.BAR";    # \x{3a3} == GREEK CAPITAL LETTER SIGMA.

( $c = $b ) =~ s/(\w+)/lc($1)/ge;
print qq{ok\n} if $c eq $a;

my $re = qr{\p{IsWord}};    # fails by just forcing re.so to be loaded by dl_init (commented it workds)
