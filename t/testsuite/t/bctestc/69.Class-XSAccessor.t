package MyClass;
use Class::XSAccessor accessors => [ 'foo', 'bar' ];

package main;

my $o = bless {}, 'MyClass';
$o->foo("ok\n");
print $o->foo;

