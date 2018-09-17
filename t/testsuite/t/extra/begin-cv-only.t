package main;

print "1..5\n";

our ( $begin, $check, $unitcheck );

BEGIN { $begin = 42 }
CHECK { $check = 43 }
UNITCHECK { $unitcheck = 44 }

print "ok 1 - begin\n" if $begin == 42;
print "ok 2 - check\n" if $check == 43;
print "ok 3 - unitcheck\n" if $unitcheck == 44;

use B qw(svref_2object);
my $gv;

my $ref_gv;
my $ref_gv_cv;

=pod

The object returned by svref_2object() doesn't hold a reference count to
the object it refers to. This may be considered a design flaw in B, but
that's what we're currently stuck with.

This means that outside of the scope of where svref_2object was called,
there's no guarantee that the value returned by that function is valid, or
even safe against crashing.

view RT #133518

=cut

eval q{
 $gv = svref_2object( \*main::BEGIN ); # need to hide the ref to the GV or we will SEGV
 $ref_gv = ref( $gv );
 $ref_gv_cv = ref( $gv->CV );
};

print "ok 4 - *main::BEGIN is a GV\n" if $ref_gv eq 'B::GV';
print "ok 5 - &main::BEGIN is a B::SPECIAL\n" if $ref_gv_cv eq 'B::SPECIAL';
