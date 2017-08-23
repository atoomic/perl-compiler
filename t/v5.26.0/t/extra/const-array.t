#!/usr/local/cpanel/3rdparty/bin/perl

use constant _OPTIONS => ( 'ok 1', 'ok 2' );

print "1..2\n";
eval q{ print join "\n", _OPTIONS(); };

1;