package B::PV;

use strict;

use B qw/cstring SVf_IsCOW SVf_ROK SVf_POK SVp_POK SVs_GMG SVs_SMG SVf_UTF8 SVf_READONLY SVs_OBJECT/;
use B::C::Config;
use B::C::Save qw/savecowpv/;
use B::C::Save::Hek qw/save_shared_he get_sHe_HEK/;
use B::C::File qw/xpvsect svsect free/;
use B::C::Helpers qw/is_shared_hek read_utf8_string get_index/;

sub SVpbm_VALID { 0x40000000 }
sub SVp_SCREAM  { 0x00008000 }    # method name is DOES

sub do_save {
    my ( $sv, $fullname, $custom ) = @_;

    #if ( !length $fullname ) {
    #    print STDERR B::C::Save::stack_flat();
    #    die("B::PV requires a \$fullname be passed to save please!");
    #}

    my ( $ix, $sym ) = svsect()->reserve($sv);
    svsect()->debug( $fullname, $sv );

    my $shared_hek = is_shared_hek($sv);

    my ( $savesym, $cur, $len, $pv, $static, $flags ) = save_pv( $sv, $fullname );

    # sv_free2 problem with !SvIMMORTAL and del_SV
    my $refcnt = $sv->REFCNT;
    if ( $fullname && $fullname eq 'svop const' ) {
        $refcnt = DEBUGGING() ? 1000 : 0x7fffffff;
    }

    if ( ref $custom ) {    # used when downgrading a PVIV / PVNV to IV
        $flags  = $custom->{flags}  if defined $custom->{flags};
        $refcnt = $custom->{refcnt} if defined $custom->{refcnt};
        $flags &= $custom->{update_flags} if defined $custom->{update_flags};
    }

    # static pv, do not destruct. test 13 with pv0 "3".
    if ( $B::C::const_strings and !$shared_hek and $flags & SVf_READONLY and !$len ) {
        $flags &= ~0x01000000;
        debug( pv => "turn off SVf_FAKE %s %s\n", cstring($pv), $fullname );
    }

    my $xpv_sym = 'NULL';
    if ( $sv->HAS_ANY ) {
        xpvsect()->comment("stash, magic, cur, len");
        my $xpv_ix = xpvsect()->sadd( "Nullhv, {0}, %u, {%u}", $cur, $len );

        $xpv_sym = sprintf( '&xpv_list[%d]', $xpv_ix );
    }

    svsect()->comment("any, refcnt, flags, sv_u");
    $savesym = $savesym eq 'NULL' ? '0' : ".svu_pv=(char*) $savesym";
    my $sv_ix = svsect()->supdatel(
        $ix,
        '%s'   => $xpv_sym,
        '%Lu'  => $refcnt,
        '0x%x' => $flags,
        '{%s}' => $savesym
    );

    return $sym;
}

sub save_pv {
    my ( $sv, $fullname ) = @_;

    my $flags = $sv->FLAGS;

    ( $flags & SVf_ROK ) and die("save_pv should never be a RV");

    my $pok = $flags & ( SVf_POK | SVp_POK );
    my $gmg = $flags & SVs_GMG;

    my ( $static, $shared_hek ) = ( 0, is_shared_hek($sv) );

    if ($shared_hek) {
        my $pv       = $sv->PV;
        my $utf8     = $flags & SVf_UTF8;
        my $orig_cur = $sv->CUR;
        my ( $shared_he, $cur ) = save_shared_he($pv);    # we know that a shared_hek as POK
        my $len = 0;

        return ( "(" . get_sHe_HEK($shared_he) . q{)->hek_key}, $cur, $len, $pv, $static, $flags );
    }

    my $pv = "";
    my ( $savesym, $cur, $len ) = savecowpv($pv);

    # overloaded VERSION symbols fail to xs boot: ExtUtils::CBuilder with Fcntl::VERSION (i91)
    # 5.6: Can't locate object method "RV" via package "B::PV" Carp::Clan
    if ($pok) {
        $pv = pack "a*", $sv->PV;    # XXX!
        $cur = ( $sv and $sv->can('CUR') and ref($sv) ne 'B::GV' ) ? $sv->CUR : length($pv);
    }
    else {
        if ( $gmg && $fullname ) {
            no strict 'refs';
            $pv = ( $fullname and ref($fullname) ) ? "${$fullname}" : '';
            $cur = length( pack "a*", $pv );
            $pok = 1;
        }
    }

    if ($pok) {
        ( $savesym, $cur, $len ) = savecowpv($pv);    # only flags as COW if it's not a reference and not an empty string
        $flags |= SVf_IsCOW;
    }
    else {
        $flags ^= SVf_IsCOW;
    }

    $fullname = '' if !defined $fullname;

    debug(
        pv => "Saving pv %s %s cur=%d, len=%d, static=%d cow=%d %s",
        $savesym, cstring($pv), $cur, $len,
        $static, $static, $shared_hek ? "shared, $fullname" : $fullname
    );

    return ( $savesym, $cur, $len, $pv, $static, $flags );
}

1;
