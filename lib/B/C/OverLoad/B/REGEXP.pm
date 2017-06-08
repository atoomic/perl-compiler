package B::REGEXP;

use strict;

use B qw/cstring RXf_EVAL_SEEN/;
use B::C::Config;
use B::C::File qw/init svsect xpvsect/;

# post 5.11: When called from B::RV::save_op not from PMOP::save precomp
sub do_save {
    my ( $sv, $fullname ) = @_;

    my $pv  = $sv->PV;
    my $cur = $sv->CUR;

    # construct original PV
    $pv =~ s/^(\(\?\^[adluimsx-]*\:)(.*)\)$/$2/;
    $cur -= length( $sv->PV ) - length($pv);
    my $cstr = cstring($pv);

    my $magic_stash = $sv->save_magic_stash;
    my $magic       = $sv->save_magic($fullname);

    # Unfortunately this XPV is needed temp. Later replaced by struct regexp.
    # STATIC HV: Static stash please.
    my $xpv_ix = xpvsect()->saddl(
        "%s"   => $magic_stash,    # xmg_stash
        "{%s}" => $magic,          # xmg_u
        "%u"   => $cur,            # xpv_cur
        "{%u}" => 0                # xpv_len_u STATIC_HV: length is 0 ???
    );
    my $xpv_sym = sprintf( "&xpv_list[%d]", $xpv_ix );

    my $ix = svsect()->sadd( "%s, %Lu, 0x%x, {NULL}", $xpv_sym, $sv->REFCNT + 1, $sv->FLAGS );
    my $sym = sprintf( "&sv_list[%d]", $ix );
    debug( rx => "Saving RX $cstr to sv_list[$ix]" );

    # replace sv_any->XPV with struct regexp. need pv and extflags
    init()->no_split;
    init()->add('{');
    init()->indent(+1);

    # Re-compile into an SV.
    init()->add("PL_hints |= HINT_RE_EVAL;") if ( $sv->EXTFLAGS & RXf_EVAL_SEEN );
    init()->sadd( 'REGEXP* regex_sv = CALLREGCOMP(newSVpvn(%s, %d), 0x%x);', $cstr, $cur, $sv->EXTFLAGS );
    init()->add("PL_hints &= ~HINT_RE_EVAL;") if ( $sv->EXTFLAGS & RXf_EVAL_SEEN );

    init()->sadd( 'SvANY(%s) = SvANY(regex_sv);', $sym );

    my $without_amp = $sym;
    $without_amp =~ s/^&//;
    init()->sadd( "%s.sv_u.svu_rx = (struct regexp*)SvANY(regex_sv);", $without_amp );
    init()->sadd( "ReANY(%s)->xmg_stash =  %s;",                       $sym, $magic_stash );
    init()->sadd( "ReANY(%s)->xmg_u.xmg_magic =  %s;",                 $sym, $magic );

    init()->indent(-1);
    init()->add('}');
    init()->split;

    svsect()->debug( $fullname, $sv );

    return $sym;
}

1;
