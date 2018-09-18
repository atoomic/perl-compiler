#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Subtest;

use B qw/svref_2object/;

use B::C;

BEGIN {
    B::C::load_heavy;    # load XS
}

use B::C::OverLoad;      # overload save with a magic wrapper
use B::C::OverLoad::B::HV ();

#*B::C::skip_B = sub { };

sub test_regular {

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

    # important to confirm we have no side effects
    @test_with_nkeys = reverse @test_with_nkeys;

    foreach my $nkeys (@test_with_nkeys) {
        my %h = map { $_ => 1 } 1 .. $nkeys;

        my $obj = svref_2object( \%h );
        my $max = $obj->MAX;
        undef %h;    # force destruction otherwise we could recycle it

        is B::HV::get_max_hash_from_keys($nkeys), $max,
          "HvMAX( with $nkeys keys ) = $max ( same as Perl )";
    }

    return;
}

sub test_custom_value {

    is B::HV::get_max_hash_from_keys(2728), 4095;
    is B::HV::get_max_hash_from_keys(2729), 4095;

    is B::HV::get_max_hash_from_keys(2730), 8191;
    is B::HV::get_max_hash_from_keys(2731), 8191;
    is B::HV::get_max_hash_from_keys(2732), 8191;

    return;
}

sub make_pl_strtab_grow {

    local $ENV{FAKE_SUBS};
    my $h_default = check_pl_strtab();
    note explain $h_default;

    foreach my $i ( 1 .. 3100 ) {
        $ENV{FAKE_SUBS} = $i;
        my $h = check_pl_strtab();
        note "$i  $h->{KEYS} / $h->{MAX}";
    }

    return;
}

test_regular();

#test_custom_value();

# perform a second test after having tested with a custom default value
test_regular();

done_testing();
exit;

sub check_pl_strtab {
    my %h;

    my $out = qx{$^X -It/lib -MPL_strtab -e 'Test::PL_strtab::run()'};
    my @lines = split( "\n", $out );
    foreach my $line (@lines) {
        my ( $k, $v ) = split( ':', $line );
        next unless $k;
        $h{$k} = $v;
    }
    return \%h;
}
