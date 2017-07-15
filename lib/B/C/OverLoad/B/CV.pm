package B::CV;

use strict;

use B::C::Flags ();

use B qw/svref_2object CVf_CONST main_cv SVf_IsCOW CVf_NAMED/;
use B::C::Debug qw/verbose/;
use B::C::Decimal qw/get_integer_value/;
use B::C::Save qw/savecowpv/;
use B::C::Save::Hek qw/save_shared_he get_sHe_HEK/;
use B::C::File qw/svsect xpvcvsect init/;
use B::C::Helpers::Symtable qw/objsym savesym/;

my $initsub_index = 0;
my $anonsub_index = 0;

sub SVt_PVFM { 14 }            # not exported by B
sub SVs_RMG  { 0x00800000 }    # has random magical methods

# from B.xs maybe we need to save more than just the RMG ones
#define MAGICAL_FLAG_BITS (SVs_GMG|SVs_SMG|SVs_RMG)

sub do_save {
    my ( $cv, $origname ) = @_;

    my $fullname = $cv->FULLNAME();
    $cv->FLAGS & 2048 and die sprintf( "Unexpected SVf_ROK found in %s\n", ref $cv );

    if ( !$cv->CONST && $cv->XSUB ) {    # xs function
        $fullname =~ s{^main::}{};

        B::C::found_xs_sub($fullname);
        return "BOOTSTRAP_XS_[[${fullname}]]_XS_BOOTSTRAP";
    }

    my ( $ix, $sym ) = svsect()->reserve($cv);
    svsect()->debug( $fullname, $cv );

    my $presumed_package = $origname;
    $presumed_package =~ s/::[^:]+$// if $presumed_package;

    # We only have a stash if NAME_HEK isn't in place. this happens when we're off an RV instead of a GV.
    my $flags = $cv->FLAGS;

    # need to survive cv_undef as there is no protection against static CVs
    my $refcnt = $cv->REFCNT;

    my $root = $cv->get_ROOT;

    # Setup the PV for the SV here cause we need to set cur and len.
    my $pv  = 'NULL';
    my $cur = $cv->CUR;
    my $len = $cv->LEN;
    if ( defined $cv->PV ) {
        ( $pv, $cur, $len ) = savecowpv( $cv->PV );
        $pv    = "(char *) $pv";
        $flags = $flags | SVf_IsCOW;
    }

    my $xcv_outside = $cv->get_cv_outside();

    my ( $xcv_file, undef, undef ) = savecowpv( $cv->FILE || '' );

    my ( $xcv_root, $startfield );
    if ( my $c_function = $cv->can_do_const_sv() ) {
        $xcv_root = sprintf( '.xcv_xsub=&%s', $c_function );
        $startfield = sprintf( '.xcv_xsubany= {(void*) %s /* xsubany */}', $cv->XSUBANY->save() );    # xcv_xsubany
    }
    else {    # default values for xcv_root and startfield
        $xcv_root = sprintf( "%s", $root ? $root->save : 0 );
        $startfield = $cv->save_optree();
    }

    xpvcvsect->comment("xmg_stash, xmg_u, xpv_cur, xpv_len_u, xcv_stash, xcv_start_u, xcv_root_u, xcv_gv_u, xcv_file, xcv_padlist_u, xcv_outside, xcv_outside_seq, xcv_flags, xcv_depth");
    my $xpvcv_ix = xpvcvsect->saddl(
        '%s'          => $cv->save_magic_stash,                    # xmg_stash
        '{%s}'        => $cv->save_magic($origname),               # xmg_u
        '%u'          => $cur,                                     # xpv_cur -- warning this is not CUR and LEN for the pv
        '{%u}'        => $len,                                     # xpv_len_u -- warning this is not CUR and LEN for the pv
        '%s'          => $cv->save_stash,                          # xcv_stash
        '{%s}'        => $startfield,                              # xcv_start_u --- OP *    xcv_start; or ANY xcv_xsubany;
        '{%s}'        => $xcv_root,                                # xcv_root_u  --- OP *    xcv_root; or void    (*xcv_xsub) (pTHX_ CV*);
        q{%s}         => $cv->get_xcv_gv_u,                        # $xcv_gv_u, # xcv_gv_u
        q{(char*) %s} => $xcv_file,                                # xcv_file
        '{%s}'        => $cv->cv_save_padlist($origname),          # xcv_padlist_u
        '(CV*)%s'     => $xcv_outside,                             # xcv_outside
        '%d'          => get_integer_value( $cv->OUTSIDE_SEQ ),    # xcv_outside_seq
        '0x%x'        => $cv->CvFLAGS,                             # xcv_flags
        '%d'          => $cv->DEPTH                                # xcv_depth
    );

    # svsect()->comment("any=xpvcv, refcnt, flags, sv_u");
    svsect->supdate( $ix, "(XPVCV*)&xpvcv_list[%u], %Lu, 0x%x, {%s}", $xpvcv_ix, $cv->REFCNT, $flags, $pv );

    return $sym;
}

{
    my %_const_sv_function = map { $_ => 'bc_const_sv_xsub' } qw{B::IV B::UV B::PV};

    sub can_do_const_sv {
        my ($cv) = @_;
        die unless $cv;
        return unless $cv->CONST && $cv->XSUB;
        my $xsubany = $cv->XSUBANY;
        my $ref     = ref $cv->XSUBANY;
        return if !$ref || $ref eq 'B::SPECIAL';

        return unless exists $_const_sv_function{$ref};

        #die "CV CONST XSUB is not implemented for $ref" unless exists $_const_sv_function{$ref};
        return $_const_sv_function{$ref};
    }
}

sub save_stash {
    my $cv = shift;

    $cv->STASH or return 'Nullhv';

    my $symbol = $cv->STASH->save;
    $symbol = q{Nullhv}       if $symbol eq 'Nullsv';
    $symbol = "(HV*) $symbol" if $symbol ne 'Nullhv';

    return $symbol;
}

sub get_cv_outside {
    my ($cv) = @_;

    my $ref = ref( $cv->OUTSIDE );

    return 0 unless $ref;

    if ( $ref eq 'B::CV' ) {
        $cv->FULLNAME or return 0;

        return 0 if ${ $cv->OUTSIDE } ne ${ main_cv() } && !$cv->is_format;
    }

    return $cv->OUTSIDE->save;
}

sub is_format {
    my $cv = shift;

    my $format_mask = SVt_PVFM() | SVs_RMG();
    return ( $cv->FLAGS & $format_mask ) == $format_mask ? 1 : 0;
}

sub cv_save_padlist {
    my ( $cv, $origname ) = @_;

    my $padlist = $cv->PADLIST;

    $$padlist or return 'NULL';
    my $fullname = $cv->get_full_name($origname);

    return $padlist->save( $fullname . ' :pad', $cv );
}

sub get_full_name {
    my ( $cv, $origname ) = @_;

    my $fullname = $cv->NAME_HEK || '';
    return $fullname if $fullname;

    my $gv     = $cv->GV;
    my $cvname = '';
    if ( $gv and $$gv ) {
        $cvname = $gv->NAME;
        my $cvstashname = $gv->STASH->NAME;
        $fullname = $cvstashname . '::' . $cvname;

        # XXX gv->EGV does not really help here
        if ( $cvname eq '__ANON__' ) {
            if ($origname) {
                $cvname = $fullname = $origname;
                $cvname =~ s/^\Q$cvstashname\E::(.*)( :pad\[.*)?$/$1/ if $cvstashname;
                $cvname =~ s/^.*:://;
                if ( $cvname =~ m/ :pad\[.*$/ ) {
                    $cvname =~ s/ :pad\[.*$//;
                    $cvname = '__ANON__' if is_phase_name($cvname);
                    $fullname = $cvstashname . '::' . $cvname;
                }
            }
            else {
                $cvname   = $gv->EGV->NAME;
                $fullname = $cvstashname . '::' . $cvname;
            }
        }

    }
    elsif ( $cv->is_lexsub($gv) ) {
        $fullname = $cv->NAME_HEK;
        $fullname = '' unless defined $fullname;
    }

    my $isconst = $cv->CvFLAGS & CVf_CONST;
    if ( !$isconst && $cv->XSUB && ( $cvname ne "INIT" ) ) {
        my $egv       = $gv->EGV;
        my $stashname = $egv->STASH->NAME;
        $fullname = $stashname . '::' . $cvname;
    }

    return $fullname;

}

sub get_xcv_gv_u {
    my ($cv) = @_;

    # $cv->CvFLAGS & CVf_NAMED
    if ( my $pv = $cv->NAME_HEK ) {
        my ($share_he) = save_shared_he($pv);
        my $xcv_gv_u = sprintf( "{.xcv_hek=%s}", get_sHe_HEK($share_he) );    # xcv_gv_u
        return $xcv_gv_u;
    }

    #GV (.xcv_gv)
    my $xcv_gv_u = $cv->GV ? $cv->GV->save : 'Nullsv';

    $xcv_gv_u = 0 if $xcv_gv_u eq 'Nullsv';

    return sprintf( "{.xcv_gv=%s}", $xcv_gv_u );
}

sub get_ROOT {
    my ($cv) = @_;

    my $root = $cv->ROOT;
    return ref $root eq 'B::NULL' ? undef : $root,
}

sub save_optree {
    my ($cv) = @_;

    my $root = $cv->get_ROOT;

    return 0 unless ( $root && $$root );

    verbose() ? B::walkoptree_slow( $root, "save" ) : B::walkoptree( $root, "save" );
    my $startfield = objsym( $cv->START );

    $startfield = objsym( $root->next ) unless $startfield;    # 5.8 autoload has only root
    $startfield = "0" unless $startfield;                      # XXX either CONST ANON or empty body

    return $startfield;
}

sub is_lexsub {
    my ( $cv, $gv ) = @_;

    # logical shortcut perl5 bug since ~ 5.19: testcc.sh 42
    return ( ( !$gv or ref($gv) eq 'B::SPECIAL' ) and $cv->can('NAME_HEK') ) ? 1 : 0;
}

sub is_phase_name {
    $_[0] =~ /^(BEGIN|INIT|UNITCHECK|CHECK|END)$/ ? 1 : 0;
}

sub FULLNAME {
    my ($cv) = @_;

    #return q{PL_main_cv} if $cv eq ${ main_cv() };
    # Do not coerce a RV into a GV during compile by calling $cv->GV on something with a NAME_HEK (RV)
    my $name = $cv->NAME_HEK;
    return $name if ($name);

    my $gv = $cv->GV;
    return q{SPECIAL} if ref $gv eq 'B::SPECIAL';

    return $gv->FULLNAME;
}

1;
