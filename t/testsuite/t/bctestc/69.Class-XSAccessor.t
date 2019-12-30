# BC_SKIP_ON_AUTOMATED_TESTING

package MyClass;
use Class::XSAccessor accessors => [ 'foo', 'bar' ];

package main;

my $o = bless {}, 'MyClass';
$o->foo("ok\n");
print $o->foo;

