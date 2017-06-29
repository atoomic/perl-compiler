my $i;
package Foo;
sub DESTROY	{ my $self = shift; print "ok $i - DESTROY " . $self->[0] ."\n" }
sub start	{ push @_, 1 }
for (1..3)	{ $i = $_; start(bless([$_])) }

