#!perl

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use FileHandle;

use B::C::InitSection::XOPs;

my %symtable;

{

    my $xops = B::C::InitSection::XOPs->new( 'my_init_xops', \%symtable, 0 );

    ok $xops->isa('B::C::InitSection'), "xops is one InitSection";
    ok $xops->isa('B::C::Section'),     "xops is one Section";

    lines_match( $xops->output(), <<'EOS', 'xops output without any XOPs' );
static void perl_my_init_xops_aaaa(pTHX)
{

}

PERL_STATIC_INLINE int perl_my_init_xops(pTHX)
{
    perl_my_init_xops_aaaa(aTHX);
    return 0;
}
EOS

}

{

    my $xops = B::C::InitSection::XOPs->new( 'my_init_xops', \%symtable, 0 );
    ok !$xops->has_values, 'xops has no values';

    $xops->xop_used_by( 'is_arrayref', '(OP*)&unop_list[42]' );
    $xops->xop_used_by( 'is_yourmum',  '(OP*)&unop_list[43]' );

    ok $xops->has_values, 'xops has some values now';

    lines_match( $xops->output(), <<'EOS', 'xops output without any XOPs' );
static void perl_my_init_xops_aaaa(pTHX)
{
    register int i;
        {
            void *ppaddr   = bc_xop_ppaddr_from_name("is_arrayref");
            int idx[1] = { 42 };

            for ( i = 0; i < 1; ++i ) {
                ( (OP*) &unop_list[ idx[i] ] )->op_ppaddr = (OP* (*)()) ppaddr;
            }
        }

        {
            void *ppaddr   = bc_xop_ppaddr_from_name("is_yourmum");
            int idx[1] = { 43 };

            for ( i = 0; i < 1; ++i ) {
                ( (OP*) &unop_list[ idx[i] ] )->op_ppaddr = (OP* (*)()) ppaddr;
            }
        }


}

PERL_STATIC_INLINE int perl_my_init_xops(pTHX)
{
    perl_my_init_xops_aaaa(aTHX);
    return 0;
}
EOS

}

{

    my $xops = B::C::InitSection::XOPs->new( 'my_init_xops', \%symtable, 0 );
    ok !$xops->has_values, 'xops has no values';

    $xops->xop_used_by( 'is_arrayref', '(OP*)&unop_list[0]' );
    $xops->xop_used_by( 'is_arrayref', '(OP*)&unop_list[1]' );
    $xops->xop_used_by( 'is_arrayref', '(OP*)&unop_list[2]' );
    $xops->xop_used_by( 'is_arrayref', '(OP*)&unop_list[3]' );
    $xops->xop_used_by( 'is_arrayref', '(OP*)&unop_list[4]' );
    
    $xops->xop_used_by( 'mycustomop',  '(OP*)&unop_list[5]' );
    
    $xops->xop_used_by( 'is_arrayref', '(OP*)&unop_list[6]' );

    lines_match( $xops->output(), <<'EOS', 'xops output without any XOPs' );
static void perl_my_init_xops_aaaa(pTHX)
{
    register int i;
        {
            void *ppaddr   = bc_xop_ppaddr_from_name("is_arrayref");
            int idx[6] = { 0, 1, 2, 3, 4, 6 };

            for ( i = 0; i < 6; ++i ) {
                ( (OP*) &unop_list[ idx[i] ] )->op_ppaddr = (OP* (*)()) ppaddr;
            }
        }

        {
            void *ppaddr   = bc_xop_ppaddr_from_name("mycustomop");
            int idx[1] = { 5 };

            for ( i = 0; i < 1; ++i ) {
                ( (OP*) &unop_list[ idx[i] ] )->op_ppaddr = (OP* (*)()) ppaddr;
            }
        }


}

PERL_STATIC_INLINE int perl_my_init_xops(pTHX)
{
    perl_my_init_xops_aaaa(aTHX);
    return 0;
}
EOS

}



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
