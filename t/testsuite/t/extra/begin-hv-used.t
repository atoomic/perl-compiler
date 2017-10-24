package Foo;

our %BEGIN;
BEGIN {
	%BEGIN = ( 1..10 );
}

package main;

=pod

We want to check that when BEGIN HV slot is used in the GV we are not ignoring it

=cut

print "1..2\n";
our %BEGIN = ( 1..4 );

print "ok 1 - \@BEGIN\n" if scalar keys %BEGIN == 2;
print "ok 2 - \@Foo::BEGIN\n" if scalar keys %Foo::BEGIN == 5;