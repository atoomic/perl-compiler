package Foo;

our @BEGIN;
BEGIN {
	@BEGIN = ( 1..10 );
}

package main;

=pod

We want to check that when BEGIN AV slot is used in the GV we are not ignoring it

=cut

print "1..2\n";
our @BEGIN = ( 1..5 );

print "ok 1 - \@BEGIN\n" if scalar @BEGIN == 5;
print "ok 2 - \@Foo::BEGIN\n" if scalar @Foo::BEGIN == 10;