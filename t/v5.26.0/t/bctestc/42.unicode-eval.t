#!/bin/env perl

use charnames ":full";
my $x = eval q{"\N{WHITE SMILING FACE}"};
print qq{ok\n};
