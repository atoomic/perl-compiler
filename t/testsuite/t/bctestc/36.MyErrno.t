package MyErrno;
use strict;

BEGIN {
    eval "sub TEST() { 123456 }; 1" or die $@;
}

package main;

print qq{:ok 1} if &MyErrno::TEST;
print qq{:ok 2} if &MyErrno::TEST == 123456;

1;
