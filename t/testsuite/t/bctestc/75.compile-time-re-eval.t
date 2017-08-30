#!perl

my $c = 0;
@a = split /-(?{ $c++ })/, "a-b-c";
print qq[ok\n] if $c == 2;
