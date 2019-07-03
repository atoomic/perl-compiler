package MyClass;

# Options can be passed as a HASH reference, if preferred,
# which can also help Perl::Tidy to format the statement correctly.
use Class::XSAccessor {

    # If the name => key values are always identical,
    # the following shorthand can be used.
    accessors   => [qw/foo bar baz/],
    constructor => 'new',
};

package main;

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
}

plan tests => 5;

my $object;    # simulate a singleton setup at compile time

BEGIN {
    $object = MyClass->new( foo => 42 );
    $object->bar(123);
}

is( ref $object, 'MyClass', "MyClass->new" );
is $object->foo, 42,    "foo was set by constructor";
is $object->bar, 123,   "bar was set at compile time";
is $object->baz, undef, "baz was unset at compile time";

$object->bar( $object->bar + 1 );
is $object->bar, 124, "bar++";
