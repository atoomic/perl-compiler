package Foo;

our $BEGIN;
BEGIN {
	$BEGIN = 'abcd';
}

package main;

=pod

We want to check that when BEGIN SV slot is used in the GV we are not ignoring it

=cut

print "1..2\n";
our $BEGIN = 'xyz';

print "ok 1 - \$BEGIN\n" if $BEGIN eq 'xyz';
print "ok 2 - \$Foo::BEGIN\n" if $Foo::BEGIN eq 'abcd';