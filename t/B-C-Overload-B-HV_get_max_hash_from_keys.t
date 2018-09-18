#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Subtest;

use B qw/svref_2object/;

use B::C::OverLoad;    # overload save with a magic wrapper
use B::C::OverLoad::B::HV ();

*B::C::skip_B = sub { };

my @test_with_nkeys = (
    0 .. 18,
    500,
    512,
    1000,
    1023,
    1024,
    2040,
    2048,
);

foreach my $nkeys (@test_with_nkeys) {
    my %h = map { $_ => 1 } 1 .. $nkeys;

    my $obj = svref_2object( \%h );
    my $max = $obj->MAX;

    is B::HV::get_max_hash_from_keys($nkeys), $max, "HvMAX( with $nkeys keys ) = $max ( same as Perl )";
}

done_testing();
exit;
