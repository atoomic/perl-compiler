package B::PVLV;

use strict;

use B q/cchar/;

use B::C::Config;
use B::C::File qw/xpvlvsect svsect init/;
use B::C::Decimal qw/ get_double_value/;

# Warning not covered by the (cpanel)core test suite...
# FIXME... add some test coverage for PVLV

sub do_save {
    my ( $sv, $fullname ) = @_;

    die("We know of no code that produces a PVLV. Please contact the busy camels immediately.");

    my ( $pvsym, $cur, $len, $pv, $static, $flags ) = B::PV::save_pv_or_rv( $sv, $fullname );
    my ( $lvtarg, $lvtarg_sym );    # XXX missing

    #struct xpvlv {
    #    _XPV_HEAD;
    #    union _xivu xiv_u;
    #    union _xnvu xnv_u;
    #    union {
    #        STRLEN  xlvu_targoff;
    #        SSize_t xlvu_stargoff;
    #    } xlv_targoff_u;
    #    STRLEN      xlv_targlen;
    #    SV*         xlv_targ;
    #    char        xlv_type;       /* k=keys .=pos x=substr v=vec /=join/re
    #                                 * y=alem/helem/iter t=tie T=tied HE */
    #    char        xlv_flags;      /* 1 = negative offset  2 = negative len
    #                                   4 = out of range (vec) */
    #};
    # STATIC HV: Static stash please.
    xpvlvsect()->comment('xmg_stash, xmg_u, xpv_cur, xpv_len_u, xiv_u, xnv_u, xlv_targoff_u, xlv_targlen, xlv_targ, xlv_type, xlv_flags');
    my $xpv_ix = xpvlvsect()->saddl(
        "%s"   => $sv->save_magic_stash,           # xmg_stash
        "{%s}" => $sv->save_magic($fullname),      # xmg_u
        "%u"   => $cur,                            # xpv_cur
        "{%u}" => $len,                            # xpv_len_u
        "%s"   => 0,                               # xiv_u - Was 0 and labeled as 0/*GvNAME later*/
        "%s"   => get_double_value( $sv->NVX ),    # xnv_u
        "%s"   => $sv->TARGOFF,                    # xlv_targoff_u
        "%s"   => $sv->TARGLEN,                    # xlv_targlen
        "%s"   => $sv->TARG,                       # xlv_targ
        "%s"   => cchar( $sv->TYPE ),              # xlv_type
        "%d"   => $sv->LvFLAGS,                    # xlv_flags # STATIC_HV: LvFLAGS is unimplemented in B
    );


    my $ix = svsect()->add(
        sprintf(
            "&xpvlv_list[%d], %Lu, 0x%x, {(char*)%s}",
            xpvlvsect()->index, $sv->REFCNT, $flags, $pvsym
        )
    );

    svsect()->debug( $fullname, $sv );

    return "&sv_list[" . $ix . "]";
}

1;
