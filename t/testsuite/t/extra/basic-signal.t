# stolen from xtestc/0192.t
# this is just checking that we can catch a basic SIGNAL

use warnings;

print qq{1..1\n};
{
   my $w;
   $SIG{__WARN__} = sub { $w = shift };
   warn 42;
   print $w =~ qr{^42} ? qq{ok 1\n} : qq{not ok 1 -:$w:\n};
}

### RESULT:ok
