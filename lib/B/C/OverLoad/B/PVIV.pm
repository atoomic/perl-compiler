package B::PVIV;

use strict;
use B::C::Config;
use B::C::File qw/xpvivsect svsect/;
use B::C::Decimal qw/get_integer_value/;
use B::C::Optimizer::DowngradePVXV qw/downgrade_pviv/;

sub do_save {
    my ( $sv, $fullname ) = @_;

    my $downgraded = downgrade_pviv( $sv, $fullname );
    return $downgraded if defined $downgraded;

    my ( $ix, $sym ) = svsect()->reserve($sv);
    svsect()->debug( $fullname, $sv );

    # save the PVIV
    my ( $savesym, $cur, $len, $pv, $static, $flags ) = B::PV::save_pv( $sv, $fullname );

    my $xpv_sym = 'NULL';
    if ( $sv->HAS_ANY ) {
        xpvivsect()->comment('STASH, MAGIC, cur, len, IVX');
        my $xpv_ix = xpvivsect()->sadd(
            "Nullhv, {0}, %u, {%u}, {%s}",
            $cur, $len, get_integer_value( $sv->IVX )
        );    # IVTYPE long

        $xpv_sym = sprintf( "&xpviv_list[%d]", $xpv_ix );
    }

    # save the pv
    svsect()->supdate( $ix, "%s, %u, 0x%x, {.svu_pv=(char*) %s}", $xpv_sym, $sv->REFCNT, $flags, $savesym );

    return $sym;
}

1;
