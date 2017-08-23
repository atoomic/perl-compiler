package MyErrno;
use strict;

BEGIN {
    eval "sub TEST() { q{xyz} }; 1" or die $@;
}

package main;

print qq{ok 1:} if &MyErrno::TEST;
print qq{ok 2:} if &MyErrno::TEST eq q{xyz};

1;
