#!perl -w

use strict;
use warnings;

use Test::More;

use B qw/svref_2object SVf_ROK/;

use B::C::OverLoad; # overload save with a magic wrapper
use B::C::OverLoad::B::IV ();
use B::C::OverLoad::B::UV ();
use B::C::OverLoad::B::RV ();
use B::C::File qw/svsect xpvivsect/;
use B::C::Helpers::Symtable qw/getsym/;

my $simple_int = 8675309;

my $iv = svref_2object( \$simple_int );

isa_ok( $iv, 'B::IV', '$simple_int' );
B::C::File::new('doesnt matter');

#*B::IV::save = B::IV::do_save;

my $got = B::IV::save( $iv, '$main::simple_int' );
is( svsect()->get( 1 ),    q{BODYLESS_UV_PTR(&sv_list[1]), 1, 0x1101, {.svu_uv=8675309U}}, "bodyless IV with 1 reference" );

clear_all();

my $second_ref = \$simple_int;
$got = B::IV::save( $iv, '$main::simple_int' );
is( svsect()->get( 1 ), 'BODYLESS_UV_PTR(&sv_list[1]), 2, 0x1101, {.svu_uv=8675309U}', "bodyless IV with 2 references once we refer to it from elsewhere" );

clear_all();

my $rv_save_called;
{
    no warnings 'redefine';
    *B::RV::save = sub { $rv_save_called++ };
}

my $rv = svref_2object( \$second_ref );
isa_ok( $rv, 'B::IV', 'A ref to the int variable' );
ok $rv->FLAGS & SVf_ROK, 'SVf_ROK enable';
$got = B::IV::do_save( $rv, '$main::second_ref' );
is $got, q{&sv_list[1]}, 'got one sv_list symbol';
is svsect()->get( 1 ), q[(void*)&sv_list[1] - sizeof(void*), 1, 0x801, {.svu_rv=&sv_list[2]}], 'the SV points to another SV';

clear_all();

my $uv_save_called;
{
    no warnings 'redefine';
    *B::UV::save = sub { $uv_save_called++ };
}

my $unsigned_int = 0 + sprintf( '%u', -1 );
my $uv = svref_2object( \$unsigned_int );
$got = B::IV::save( $uv, '$main::unsigned_int' );
is( $uv_save_called, 1, "B::UV::save is called on an unsigned integer" );

done_testing();
exit;

sub clear_all {
    B::C::Helpers::Symtable::clearsym();
    B::C::File::re_initialize();
}
