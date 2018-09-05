#!perl

print "1..1\n";

my ( $x, $y ) = qw{winter summer};
my $concat = "x=$x y=$y";

print "# $concat\n";
print qq[ok 1\n] if $concat eq 'x=winter y=summer';
