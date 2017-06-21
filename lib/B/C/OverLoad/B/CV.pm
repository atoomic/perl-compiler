package B::CV;

use strict;

use B::C::Flags ();

use B qw/svref_2object CVf_CONST main_cv SVf_IsCOW/;
use B::C::Config;
use B::C::Decimal qw/get_integer_value/;
use B::C::Save qw/savecowpv/;
use B::C::Save::Hek qw/save_shared_he get_sHe_HEK/;
use B::C::File qw/svsect xpvcvsect init/;
use B::C::Helpers::Symtable qw/objsym savesym/;

my $initsub_index = 0;
my $anonsub_index = 0;

sub do_save {
    my ( $cv, $origname ) = @_;
    debug( cv => "CV ==  %s", $origname );

    my $fullname = $cv->FULLNAME();

    if ( !$cv->CONST && $cv->XSUB ) {    # xs function
        $fullname =~ s{^main::}{};

        B::C::found_xs_sub($fullname);
        return "BOOTSTRAP_XS_[[${fullname}]]_XS_BOOTSTRAP";
    }

    my $sv_ix = svsect()->add('FAKE_GV');
    my $sym = savesym( $cv, "&sv_list[$sv_ix]" );

    my $presumed_package = $origname;
    $presumed_package =~ s/::[^:]+$// if $presumed_package;

    # We only have a stash if NAME_HEK isn't in place. this happens when we're off an RV instead of a GV.
    my $cv_stash = 'NULL';
    if ( !$cv->NAME_HEK ) {
        $cv_stash = typecast_stash_save( $cv->STASH->save );
    }

    # need to survive cv_undef as there is no protection against static CVs
    my $refcnt = $cv->REFCNT + 1;

    my $root = $cv->get_ROOT;

    my $startfield = $cv->save_optree();

    # Setup the PV for the SV here cause we need to set cur and len.
    my $pv    = 'NULL';
    my $flags = $cv->FLAGS;
    my $cur   = $cv->CUR;
    my $len   = $cv->LEN;
    if ( defined $cv->PV ) {
        ( $pv, $cur, $len ) = savecowpv( $cv->PV );
        $pv    = "(char *) $pv";
        $flags = $flags | SVf_IsCOW;
    }

    my $xcv_outside = $cv->get_cv_outside();

    my ( $xcv_file, undef, undef ) = savecowpv( $cv->FILE || '' );

    xpvcvsect->comment("xmg_stash, xmg_u, xpv_cur, xpv_len_u, xcv_stash, xcv_start_u, xcv_root_u, xcv_gv_u, xcv_file, xcv_padlist_u, xcv_outside, xcv_outside_seq, xcv_flags, xcv_depth");

    my $xpvcv_ix = xpvcvsect->saddl(
        '%s'          => $cv->save_magic_stash,                    # xmg_stash
        '{%s}'        => $cv->save_magic($origname),               # xmg_u
        '%u'          => $cur,                                     # xpv_cur -- warning this is not CUR and LEN for the pv
        '{%u}'        => $len,                                     # xpv_len_u -- warning this is not CUR and LEN for the pv
        '%s'          => $cv_stash,                                # xcv_stash
        '{%s}'        => $startfield,                              # xcv_start_u
        "{s\\_%x}"    => $root ? $$root : 0,                       # xcv_root_u
        q{%s}         => $cv->get_xcv_gv_u,                        # $xcv_gv_u, # xcv_gv_u
        q{(char*) %s} => $xcv_file,                                # xcv_file
        '{%s}'        => $cv->cv_save_padlist($origname),          # xcv_padlist_u
        '(CV*)%s'     => $xcv_outside,                             # xcv_outside
        '%d'          => get_integer_value( $cv->OUTSIDE_SEQ ),    # xcv_outside_seq
        '0x%x'        => $cv->CvFLAGS,                             # xcv_flags
        '%d'          => $cv->DEPTH                                # xcv_depth
    );

    if ( $xcv_outside eq '&PL_main_cv' ) {
        init()->sadd( "xpvcv_list[%u].xcv_outside = (CV*) &PL_main_cv;", $xpvcv_ix );
        xpvcvsect->update_field( $xpvcv_ix, 10, 'NULL /* PL_main_cv */' );
    }

    # STATIC_HV: We don't think the sv_u is ever set in the SVCV so this check might be wrong
    # we are not saving the svu for a CV, all evidence indicates that the value is null (always?)
    # CVf_NAMED flag lets you know to use the HEK for the name
    #warn qq{======= Unsaved PV for a CV - $origname - } . $cv->PV if ( length( $cv->PV ) );

    # svsect()->comment("any=xpvcv, refcnt, flags, sv_u");

    svsect->supdate( $sv_ix, "(XPVCV*)&xpvcv_list[%u], %Lu, 0x%x, {%s}", $xpvcv_ix, $cv->REFCNT + 1, $flags, $pv );

    return $sym;
}

sub typecast_stash_save {
    my $symbol = shift or return;
    $symbol = q{Nullhv}       if $symbol eq 'Nullsv';
    $symbol = "(HV*) $symbol" if $symbol ne 'Nullhv';

    return $symbol;
}

sub get_cv_outside {
    my ($cv) = @_;
    my $xcv_outside = ${ $cv->OUTSIDE };
    if ( $xcv_outside == ${ main_cv() } ) {

        # Provide a temp. debugging hack for CvOUTSIDE. The address of the symbol &PL_main_cv
        # is known to the linker, the address of the value PL_main_cv not. This is set later
        # (below) at run-time.
        $xcv_outside = '&PL_main_cv';
    }
    elsif ( ref( $cv->OUTSIDE ) eq 'B::CV' ) {
        $xcv_outside = 0;    # just a placeholder for a run-time GV
    }
    elsif ($xcv_outside) {
        $cv->OUTSIDE->save;
    }

    return $xcv_outside;
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

    my $fullname = '';

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
        my $share_he = save_shared_he($pv);
        my $xcv_gv_u = sprintf( "{.xcv_hek=%s }", get_sHe_HEK($share_he) );    # xcv_gv_u
        return $xcv_gv_u;
    }

    #GV (.xcv_gv)
    my $xcv_gv_u = $cv->GV ? $cv->GV->save : 'Nullsv';

    return $xcv_gv_u if $xcv_gv_u eq 'Nullsv';

    return sprintf( "{ .xcv_gv = %s }", $xcv_gv_u );
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

    my $gv = $cv->GV;

    my $ppname;
    my $fullname;

    if ( $cv->is_lexsub($gv) ) {
        my $name = $cv->can('NAME_HEK') ? $cv->NAME_HEK : "anonlex";
        $ppname   = "pp_lexsub_" . $name;
        $fullname = "<lex>" . $name;
    }
    elsif ( $gv and $$gv ) {
        my ( $stashname, $gvname );
        $stashname = $gv->STASH->NAME;
        $gvname    = $gv->NAME;
        $fullname  = $stashname . '::' . $gvname;
        $ppname    = ( ${ $gv->FORM } == $$cv ) ? "pp_form_" : "pp_sub_";
        if ( $gvname ne "__ANON__" ) {
            $ppname .= ( $stashname eq "main" ) ? $gvname : "$stashname\::$gvname";
            $ppname =~ s/::/__/g;
            $ppname =~ s/(\W)/sprintf("0x%x", ord($1))/ge;
            if ( $gvname eq "INIT" ) {
                $ppname .= '_' . $initsub_index;
                $initsub_index++;
            }
        }
    }
    if ( !$ppname ) {
        $ppname = "pp_anonsub_$anonsub_index";
        $anonsub_index++;
    }

    my $startfield = B::C::saveoptree( $ppname, $root, $cv->START, $cv->PADLIST->ARRAY );    # XXX padlist is ignored

    # XXX missing cv_start for AUTOLOAD on 5.8
    $startfield = objsym( $root->next ) unless $startfield;                                  # 5.8 autoload has only root
    $startfield = "0" unless $startfield;                                                    # XXX either CONST ANON or empty body

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

    # Do not coerce a RV into a GV during compile by calling $cv->GV on something with a NAME_HEK (RV)
    my $name = $cv->NAME_HEK;
    return $name if ($name);

    return $cv->GV->STASH->NAME . '::' . $cv->GV->NAME;
}

1;
