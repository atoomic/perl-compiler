package MyClass;
use Class::XSAccessor replace => 1,       # Replace existing methods (if any)
  constructor                 => 'new',
  getters                     => {
    get_foo => 'foo',                     # 'foo' is the hash key to access
    get_bar => 'bar',
  },
  setters => {
    set_foo => 'foo',
    set_bar => 'bar',
  },
  accessors => {
    foo => 'foo',
    bar => 'bar',
  },

  # "predicates" is an alias for "defined_predicates"
  defined_predicates => {
    defined_foo => 'foo',
    defined_bar => 'bar',
  },
  exists_predicates => {
    has_foo => 'foo',
    has_bar => 'bar',
  },
  lvalue_accessors => {    # see below
    baz => 'baz',          # ...
  },
  true  => [ 'is_token', 'is_whitespace' ],
  false => ['significant'];

package main;

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
}

plan tests => 10;

my $object = MyClass->new();
is( ref $object, 'MyClass', "MyClass->new" );

is $object->get_foo, undef, "get_foo";
ok $object->set_foo('foo_value'), "set_foo";
is $object->get_foo, 'foo_value', "get_foo";

ok $object->set_bar('bar_value'), "set_bar";
is $object->get_foo, 'foo_value', "get_foo";
is $object->get_bar, 'bar_value', "get_bar";

is $object->is_token,    1,  'is_token = true';
is $object->significant, '', 'significant = false';

$object->baz = 42;
is $object->baz, 42, "lvalue_accessors";
