package TestArray;

use Class::XSAccessor::Array
  constructor => 'new',
  getters => {
    get_foo => 0, # 0 is the array index to access
    get_bar => 1,
  },
  setters => {
    set_foo => 0,
    set_bar => 1,
  },
  accessors => { # a mutator
    buz => 2,
  },
  predicates => { # test for definedness
    has_buz => 2,
  },
  lvalue_accessors => { # see below
    baz => 3,
  },
  true => [ 'is_token', 'is_whitespace' ],
  false => [ 'significant' ];

package main;

BEGIN {
     chdir 't' if -d 't';
     require './test.pl';
}

plan tests => 9;

my $object = TestArray->new();
is( ref $object, 'TestArray', "TestArray->new" );

is $object->get_foo, undef, "get_foo";
ok $object->set_foo('foo_value'), "set_foo";
is $object->get_foo, 'foo_value', "get_foo";

ok $object->set_bar('bar_value'), "set_bar";
is $object->get_foo, 'foo_value', "get_foo";
is $object->get_bar, 'bar_value', "get_bar";

is $object->is_token, 1, 'is_token = true';
is $object->significant, '', 'significant = false';
