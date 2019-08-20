#!perl

package Foo;

our %CHECK;

CHECK {
    %CHECK = ( CHECK => 'whatever' );
}

package main;

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
}

my $x;
CHECK { $x = 42 }

plan tests => 4;

is $x, 42, "x set in CHECK block";

my $CHECK = 1234;
is $CHECK, 1234, '$CHECK scalar';
our %CHECK = ( key => 'value' );
is $CHECK{key},        'value',    'hash $CHECK{key}';
is $Foo::CHECK{CHECK}, 'whatever', q[$Foo::CHECK{CHECK}];

