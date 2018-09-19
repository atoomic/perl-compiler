#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use B::C::OverLoad::B::HV ();

is(B::HV::nextPowerOf2(3), 4, "3");
is(B::HV::nextPowerOf2(4), 8, "4");
is(B::HV::nextPowerOf2(5), 8, "5");
is(B::HV::nextPowerOf2(6), 8, "6");
is(B::HV::nextPowerOf2(7), 8, "7");
is(B::HV::nextPowerOf2(8), 16, "8");
is(B::HV::nextPowerOf2(9), 16, "9");
is(B::HV::nextPowerOf2(10), 16, "10");

done_testing();
exit;