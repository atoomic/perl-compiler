package MyErrno;
use strict;

BEGIN {
    eval "sub TEST() { 123456 }; 1" or die $@;
}

package main;
print qq{ok\n} if &MyErrno::TEST;


