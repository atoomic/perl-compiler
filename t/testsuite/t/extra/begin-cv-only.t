package main;

print "1..4\n";

our ( $begin, $check, $unitcheck );

BEGIN { $begin = 42 }
CHECK { $check = 43 }
UNITCHECK { $unitcheck = 44 }

print "ok 1 - begin\n" if $begin == 42;
print "ok 2 - check\n" if $check == 43;
print "ok 3 - unitcheck\n" if $unitcheck == 44;

use B qw(svref_2object);
my $gv;
eval q{
 $gv = svref_2object( \*main::BEGIN ); # need to hide the ref to the GV or we will SEGV
};

print "ok 4 - *main::BEGIN is a GV\n" if ref($gv) eq 'B::GV';
#print "ok 5 - &main::BEGIN is a B::SPECIAL\n" if ref($gv->CV) eq 'B::SPECIAL';
