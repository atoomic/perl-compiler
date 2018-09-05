#!perl

use utf8;
binmode STDOUT, ":utf8";

print "1..1\n";

my ( $x, $y ) = ( 'winter', "summ[\x{263a}]r" );
my $concat = "x=$x y=$y";

print "# $concat\n";
print qq[ok 1\n] if $concat eq 'x=winter y=summ[☺]r';
