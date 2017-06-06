package B::IO;

use strict;

use B qw/cstring cchar svref_2object/;
use B::C::Config;
use B::C::Save qw/savecowpv/;
use B::C::File qw/init init2 svsect xpviosect/;
use B::C::Helpers::Symtable qw/savesym/;

sub do_save {
    my ( $io, $fullname ) = @_;

    #return 'NULL' if $io->IsSTD($fullname);

    my $xmg_stash = B::CV::typecast_stash_save( $io->SvSTASH->save );

    my ( $xio_top_name,    undef, undef ) = savecowpv( $io->TOP_NAME    || '' );
    my ( $xio_fmt_name,    undef, undef ) = savecowpv( $io->FMT_NAME    || '' );
    my ( $xio_bottom_name, undef, undef ) = savecowpv( $io->BOTTOM_NAME || '' );

    my $top_gv    = $io->TOP_GV->save;
    my $fmt_gv    = $io->FMT_GV->save;
    my $bottom_gv = $io->BOTTOM_GV->save;
    foreach ( $top_gv, $fmt_gv, $bottom_gv ) {
        $_ = 'NULL' if ( $_ eq 'Nullsv' );
    }

    xpviosect()->comment( 'xmg_stash, xmg_u, xpv_cur, xpv_len_u, xiv_u, xio_ofp, xio_dirpu, xio_page, xio_page_len, xio_lines_left, xio_top_name, ' . 'xio_top_gv, xio_fmt_name, xio_fmt_gv, xio_bottom_name, xio_bottom_gv, xio_type, xio_flags' );
    my $xpvio_ix = xpviosect()->sadd(
        "%s, {%s}, %u, %u, /*end of head*/ {.xivu_uv=0}/*xiv_u ???*/, (PerlIO*) 0, {.xiou_any =(void*)NULL} /* dirpu ??? */, %d, %d, %d, (char*)%s, (GV*)%s, (char*)%s, (GV*)%s, (char*)%s, (GV*) %s, '%s', 0x%x",
        $xmg_stash,                    # xmg_stash
        $io->save_magic($fullname),    # xmg_u
        $io->CUR,                      # xpv_cur
        $io->LEN,                      # xpv_len_u
                                       # xiv_u
                                       # xio_ofp
                                       # xio_dirpu
        $io->PAGE,                     # xio_page
        $io->PAGE_LEN,                 # xio_page_len
        $io->LINES_LEFT,               # xio_lines_left
        $xio_top_name,                 # xio_top_name
        $top_gv,                       # xio_top_gv
        $xio_fmt_name,                 # xio_fmt_name
        $fmt_gv,                       # xio_fmt_gv
        $xio_bottom_name,              # xio_bottom_name
        $bottom_gv,                    # xio_bottom_gv
        $io->IoTYPE,                   # xio_type
        $io->IoFLAGS,                  # xio_flags
    );

    # svsect()->comment("any=xpvcv, refcnt, flags, sv_u");
    my $sv_ix = svsect->sadd( "(XPVIO*)&xpvio_list[%u], %Lu, 0x%x, {%s}", $xpvio_ix, $io->REFCNT + 1, $io->FLAGS, '0' );

    return savesym( $io, "&sv_list[$sv_ix]" );
}

1;
