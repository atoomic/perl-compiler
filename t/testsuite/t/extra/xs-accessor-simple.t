#!perl

package Person;

use Class::XSAccessor {
    constructor => 'new',
    accessors   => [ 'name', 'email' ],
};

package main;

print "1..4\n";

my $who = Person->new( name => q[testify] );

print "ok 1 - accessor not optimized\n"    if $who->name eq 'testify';
print "ok 2 - accessor is now optimized\n" if $who->name eq 'testify';

# now set a value and access it
print "ok 3 - updating name\n" if $who->name('updated');
print "ok 4 - name was updated\n" if $who->name eq 'updated';
