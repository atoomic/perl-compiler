#!./perl

# extract from op/sub.t

use feature 'lexical_subs';
no warnings 'experimental::lexical_subs';

my sub not_constantm () { 42 }

sub do_caller { my @caller = caller(1) }

sub x { do_caller() }

{
    sub re::regmust{}
    bless \&re::regmust; # force DESTROY
    #DESTROY { print qq{DESTROYED\n} }
    no warnings;
    require re;
    x();
}

print qq[ok\n];
