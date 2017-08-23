#!./perl

# Assigning a glob-with-sub to a glob that has lost its stash works
# extract from op/gv.t
#
our $x;
our $glob;

$x = eval {
    sub greck;
    $glob = \*phing::foo;
    delete $::{"phing::"};
    *$glob = *greck;
};

# eval q{use Devel::Peek; Dump($x) };

undef $x;
print qq{ok\n};
