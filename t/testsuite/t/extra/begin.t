#!perl

package Foo;

our %BEGIN;

BEGIN {
    %BEGIN = ( BEGIN => 'whatever' );
}

package main;

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
}

my $x;
BEGIN { $x = 42 }

plan tests => 4;

is $x, 42, "x set in BEGIN block";

my $BEGIN = 1234;
is $BEGIN, 1234, '$BEGIN scalar';
our %BEGIN = ( key => 'value' );
is $BEGIN{key},        'value',    'hash $BEGIN{key}';
is $Foo::BEGIN{BEGIN}, 'whatever', q[$Foo::BEGIN{BEGIN}];

