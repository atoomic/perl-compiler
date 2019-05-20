#!perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use FileHandle;

use B::C::InitSection::Vtables;

my %symtable;

my $vtables = B::C::InitSection::Vtables->new( 'my_init_vtable', \%symtable, 0 );

ok $vtables->isa('B::C::InitSection'), "vtables is one InitSection";
ok $vtables->isa('B::C::Section'),     "vtables is one Section";

lines_match( $vtables->output(), <<'EOS', 'vtables output without any magic' );
static void perl_my_init_vtable_aaaa(pTHX)
{

}

PERL_STATIC_INLINE int perl_my_init_vtable(pTHX)
{
    perl_my_init_vtable_aaaa(aTHX);
    return 0;
}
EOS

# reset the vtable
$vtables = B::C::InitSection::Vtables->new( 'my_init_vtable', \%symtable, 0 );
ok !$vtables->has_values, 'vtables has no values';
foreach my $id ( 1 .. 4 ) {
    $vtables->add_pvmg( $id, 'backref' );
}

foreach my $id ( 5 .. 7 ) {
    $vtables->add_pvmg( $id, 'hints' );
}

$vtables->add_pvmg( 8, 'backref' );
$vtables->add_pvmg( 9, 'sv' );

ok $vtables->has_values, 'vtables has some values before being flushed';

lines_match( $vtables->output(), <<'EOS', 'vtables output without any magic' );
static void perl_my_init_vtable_aaaa(pTHX)
{
    register int i;
    
	for (i=1; i<=4; ++i) {
		magic_list[i].mg_virtual = (MGVTBL*) &PL_vtbl_backref;
	}

    
	for (i=5; i<=7; ++i) {
		magic_list[i].mg_virtual = (MGVTBL*) &PL_vtbl_hints;
	}

    magic_list[8].mg_virtual = (MGVTBL*) &PL_vtbl_backref;
    magic_list[9].mg_virtual = (MGVTBL*) &PL_vtbl_sv;

}

PERL_STATIC_INLINE int perl_my_init_vtable(pTHX)
{
    register int i;
    perl_my_init_vtable_aaaa(aTHX);
    return 0;
}
EOS

done_testing;

sub lines_match {
    my ( $got, $expect, $label ) = @_;

    $got    //= '';
    $expect //= '';

    my @got_lines = split /\n/, $got;
    my @expect_lines = map { s{^\s+}{}; qr{^\s*\Q$_\E\s*$} } split /\n/, $expect;

    my $ok = like \@got_lines, \@expect_lines, $label or diag $got;
    return $ok;
}
