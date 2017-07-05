package B::GV;

use strict;

use B qw/cstring svref_2object SVt_PVGV SVf_ROK SVf_UTF8 SVf_AMAGIC/;

use B::C::Config;
use B::C::Save::Hek qw/save_shared_he get_sHe_HEK/;
use B::C::File qw/init init_static_assignments gvsect gpsect xpvgvsect init_bootstraplink/;
use B::C::Helpers::Symtable qw/objsym savesym/;

my %gptable;

sub Save_HV()   { 1 }
sub Save_AV()   { 2 }
sub Save_SV()   { 4 }
sub Save_CV()   { 8 }
sub Save_FORM() { 16 }
sub Save_IO()   { 32 }
sub Save_FILE() { 64 }

sub _savefields_to_str {
    my $i = shift;
    return '' unless debug('gv') && $i;
    my $s = qq{$i: };
    $s .= 'HV '   if $i & Save_HV();
    $s .= 'AV '   if $i & Save_AV();
    $s .= 'SV '   if $i & Save_SV();
    $s .= 'CV '   if $i & Save_CV();
    $s .= 'FORM ' if $i & Save_FORM();
    $s .= 'IO '   if $i & Save_IO();
    $s .= 'FILE ' if $i & Save_FILE();

    return $s;
}

my $CORE_SYMS = {
    'main::ENV'  => 'PL_envgv',
    'main::ARGV' => 'PL_argvgv',
};

# These variables are the proxy variables we will use to save @_ and $_
our $under = '';
our @under = ();

sub do_save {
    my ( $gv, $name ) = @_;

    # return earlier for special cases
    return $CORE_SYMS->{ $gv->get_fullname } if $gv->is_coresym();

    # STATIC_HV need to handle $0

    my $gv_ix = gvsect()->add('FAKE_GV');
    gvsect()->debug( $gv->get_fullname() );

    my $gvsym = sprintf( '&gv_list[%d]', $gv_ix );
    savesym( $gv, $gvsym );    # cache it early as eGV might be ourself

    my $savefields = get_savefields( $gv, $gv->get_fullname() );

    debug( gv => '===== GV::do_save for %s [ savefields=%s ] ', $gv->get_fullname(), _savefields_to_str($savefields) );

    my $gpsym = $gv->savegp_from_gv($savefields);

    my $stash_symbol = $gv->get_stash_symbol();

    my $magic_stash = $gv->FLAGS & SVf_AMAGIC ? $stash_symbol : q{NULL};

    my $namehek = q{NULL};
    if ( my $gvname = $gv->NAME ) {
        my ($share_he) = save_shared_he($gvname);
        $namehek = get_sHe_HEK($share_he);
    }

    xpvgvsect()->comment("stash, magic, cur, len, xiv_u={.xivu_namehek=}, xnv_u={.xgv_stash=}");
    my $xpvg_ix = xpvgvsect()->saddl(

        # _XPV_HEAD
        "%s"                => $magic_stash,              # HV* xmg_stash;      /* class package */
        "{%s}"              => $gv->save_magic($name),    # union _xmgu xmg_u;
        '%d'                => $gv->CUR,                  # STRLEN  xpv_cur;        /* length of svu_pv as a C string */
        '{.xpvlenu_len=%d}' => $gv->LEN,                  # union xpv_len_u - xpvlenu_len or xpvlenu_pv

        # custom fields for xpvgv
        '{.xivu_namehek=(HEK*)%s}' => $namehek,           # union _xivu xiv_u - the namehek (HEK*)
        '{.xgv_stash=%s}'          => $stash_symbol,      # union _xnvu xnv_u - The symbol for the HV stash. Which field is it??
    );
    xpvgvsect()->debug( $gv->get_fullname() );
    my $xpvgv = sprintf( 'xpvgv_list[%d]', $xpvg_ix );

    {
        gvsect()->comment("XPVGV*  sv_any,  U32     sv_refcnt; U32     sv_flags; union   { gp* } sv_u # gp*");

        # replace our FAKE entry above
        gvsect()->supdatel(
            $gv_ix,
            "&%s"               => $xpvgv,                # XPVGV*  sv_any
            "%u"                => $gv->REFCNT,           #  sv_refcnt - +1 to make it immortal
            "0x%x"              => $gv->FLAGS,            # sv_flags
            "{.svu_gp=(GP*)%s}" => $gpsym,                # GP* sv_u - plug the gp in our sv_u slot
        );
    }

    debug( gv => 'Save for %s = %s VS %s', $gv->get_fullname(), $gvsym, $gv->NAME );

    # TODO: split the fullname and plug all of them in known territory...
    # relies on template logic to preserve the hash structure...

    #my @namespace = split( '::', $gv->get_fullname() );

    # FIXME... need to plug it to init()->sadd( "%s = %s;", $sym, gv_fetchpv_string( $name, $gvadd, 'SVt_PV' ) );

    # STATIC_HV: Is there a way to do this up on the xpvgvsect()->sadd line ??

    return $gvsym;
}

sub get_package {
    my $gv = shift;

    return '__ANON__' if ref( $gv->STASH ) eq 'B::SPECIAL';
    return $gv->STASH->NAME;
}

sub is_coresym {
    my $gv = shift;

    return $CORE_SYMS->{ $gv->get_fullname() } ? 1 : 0;
}

sub get_fullname {
    my $gv = shift;

    return $gv->get_package() . "::" . $gv->NAME();
}

my %saved_gps;

# hardcode the order of GV elements, so we can use macro instead of indexes
sub GP_IX_SV()     { 0 }
sub GP_IX_IO()     { 1 }
sub GP_IX_CV()     { 2 }
sub GP_IX_CVGEN () { 3 }
sub GP_IX_REFCNT() { 4 }
sub GP_IX_HV()     { 5 }
sub GP_IX_AV()     { 6 }
sub GP_IX_FORM()   { 7 }
sub GP_IX_GV()     { 8 }
sub GP_IX_LINE()   { 9 }
sub GP_IX_FLAGS()  { 10 }
sub GP_IX_HEK()    { 11 }

# FIXME todo and move later to B/GP.pm ?
sub savegp_from_gv {
    my ( $gv, $savefields ) = @_;

    # no GP to save there...
    return 'NULL' unless $gv->isGV_with_GP and $gv->GP;

    # B limitation GP is just a number not a reference so we cannot use objsym / savesym
    my $gp = $gv->GP;
    return $saved_gps{$gp} if defined $saved_gps{$gp};

    my $gvname   = $gv->NAME;
    my $fullname = $gv->get_fullname;

    # cannot do this as gp is just a number
    #my $gpsym = objsym($gp);
    #return $gpsym if defined $gpsym;

    # gp fields initializations
    # gp_cvgen: not set, no B api ( could be done in init section )
    my ( $gp_sv, $gp_io, $gp_cv, $gp_cvgen, $gp_hv, $gp_av, $gp_form ) = ( '(SV*)&PL_sv_undef', 'NULL', 'NULL', 0, 'NULL', 'NULL', 'NULL' );

    my $gp_egv = $gv->save_egv();

    # walksymtable creates an extra reference to the GV (#197): STATIC_HV: Confirm this is actually a true statement at this point.
    my $gp_refcount = $gv->GvREFCNT;    # +1 for immortal: do not free our static GVs

    my $gp_line = $gv->LINE;            # we want to use GvLINE from B.xs
                                        # present only in perl 5.22.0 and higher. this flag seems unused ( saving 0 for now should be similar )

    if ( !$gv->is_empty ) {

        # S32 INT_MAX
        $gp_line = $gp_line > 2147483647 ? 4294967294 - $gp_line : $gp_line;
    }

    my $gp_flags = $gv->GPFLAGS;        # PERL_BITFIELD32 gp_flags:1; ~ unsigned gp_flags:1
    die("gp_flags seems used now ???") if $gp_flags;    # STATIC_HV: Does removing this die fix any tests?

    # gp_file_hek is only saved for non-stashes.
    my $gp_file_hek = q{NULL};
    if ( $fullname !~ /::$/ and $gv->FILE ne 'NULL' ) {    # and !$B::C::optimize_cop
        ($gp_file_hek) = save_shared_he( $gv->FILE );      # use FILE instead of FILEGV or we will save the B::GV stash
    }

    my $gp_ix = gpsect()->add('FAKE_GP');

    $gp_sv = $gv->save_gv_sv($fullname) if $savefields & Save_SV;
    $gp_av = $gv->save_gv_av($fullname) if $savefields & Save_AV;
    $gp_hv = $gv->save_gv_hv($fullname) if $savefields & Save_HV;
    $gp_cv = $gv->save_gv_cv( $fullname, $gp_ix ) if $savefields & Save_CV;
    $gp_form = $gv->save_gv_format($fullname) if $savefields & Save_FORM;    # FIXME incomplete for now

    my $io_sv;
    ( $gp_io, $io_sv ) = $gv->save_gv_io($fullname) if $savefields & Save_IO;    # FIXME: get rid of sym
    $gp_sv = $io_sv if $io_sv;
    gpsect()->comment('SV, gp_io, CV, cvgen, gp_refcount, HV, AV, CV* form, GV, line, flags, HEK* file');

    gpsect()->supdatel(
        $gp_ix,
        "(SV*) %s"           => $gp_sv,
        "(IO*) %s"           => $gp_io,
        "(CV*) %s"           => $gp_cv,
        "%d"                 => $gp_cvgen,
        "%u"                 => $gp_refcount,
        "%s"                 => $gp_hv,
        "%s"                 => $gp_av,
        "(CV*) %s"           => $gp_form,
        "(GV*) %s /* eGV */" => $gp_egv,
        "%u"                 => $gp_line,
        "0x%x"               => $gp_flags,
        "%s"                 => get_sHe_HEK($gp_file_hek),
    );
    gpsect()->debug( $gv->get_fullname() );
    $saved_gps{$gp} = sprintf( "&gp_list[%d]", $gp_ix );

    #print STDERR "===== GP:$gp_ix SV:$gp_sv, AV:$gp_av, HV:$gp_hv, CV:$gp_cv \n";
    # we can only use static values for sv, av, hv, cv, if they are coming from a static list

    my @postpone = (
        [ 'gp_sv', GP_IX_SV(), $gp_sv ],
        [ 'gp_av', GP_IX_AV(), $gp_av ],
        [ 'gp_hv', GP_IX_HV(), $gp_hv ],
        [ 'gp_cv', GP_IX_CV(), $gp_cv ],
    );

    # Find things that can't be statically compiled and defer them
    foreach my $check (@postpone) {
        my ( $field_name, $field_ix, $field_v ) = @$check;

        # if the value is null or using a static list, then it's fine
        # when it s a bootstrap XS CV no need to set it later, the init_bootstraplink is going to do it for us (no need to redo it)
        next if $field_v =~ qr{null}i or $field_v =~ qr{list} or $field_v =~ qr{^s\\_\S+$} or $field_v =~ qr{BOOTSTRAP_XS_};

        # replace the value by a null one
        debug( gv => q{Cannot use static value '%s' for gp_list[%d].%s => postpone to init}, $field_v, $gp_ix, $field_name );
        gpsect()->update_field( $gp_ix, $field_ix, 'NULL' );

        # postpone the setting to init section
        my $deferred_init = $field_name eq 'gp_cv' ? init() : init_static_assignments();
        $deferred_init->sadd( q{gp_list[%d].%s = %s; /* deferred GV initialization for %s */}, $gp_ix, $field_name, $field_v, $fullname );
    }

    return $saved_gps{$gp};
}

# hardcode the order of GV elements, so we can use macro instead of indexes
sub GV_IX_STASH ()     { 0 }
sub GV_IX_MAGIC ()     { 1 }
sub GV_IX_CUR ()       { 2 }
sub GV_IX_LEN ()       { 3 }
sub GV_IX_NAMEHEK ()   { 4 }
sub GV_IX_XGV_STASH () { 5 }

sub get_stash_symbol {
    my ($gv) = @_;

    my @namespace = split( '::', $gv->get_fullname() );
    pop @namespace;
    my $stash_name = join "::", @namespace;
    $stash_name .= '::';

    no strict 'refs';
    return svref_2object( \%{$stash_name} )->save($stash_name);
}

sub save_egv {
    my ($gv) = @_;

    return q{NULL} if $gv->is_empty;

    my $egv = $gv->EGV;
    return q{NULL} if ref($egv) eq 'B::SPECIAL' || ref( $egv->STASH ) eq 'B::SPECIAL';

    # if it's the same do a static assignment ? (probably not required)
    #if ( $$gv == $$egv ) {
    #    warn "Same GV for ??? " . $egv->save;
    #}

    return $egv->save;
}

sub save_gv_sv {
    my ( $gv, $fullname ) = @_;

    my $gvsv = $gv->SV;
    return 'NULL' unless $$gvsv;

    #my $gvname  = $gv->NAME;
    # STATIC_HV: We think this special case needs to go away but don't have proof yet.
    # Reported in https://code.google.com/archive/p/perl-compiler/issues/91
    #if ( $gvname && $gvname eq 'VERSION' and $gvsv->FLAGS & SVf_ROK ) {
    #    die ("STATIC_HV: DEAD CODE??");
    #    my $package = $gv->get_package();
    #    debug( gv => "Strip overload from $package\::VERSION, fails to xs boot (issue 91)" );
    #    my $rv     = $gvsv->object_2svref();
    #    my $origsv = $$rv;
    #    no strict 'refs';
    #    ${$fullname} = "$origsv";
    #    return svref_2object( \${$fullname} )->save($fullname);
    #}

    if ( $fullname eq 'main::_' ) {
        $gvsv = svref_2object( \$under );
    }

    return $gvsv->save($fullname);
}

sub save_gv_av {    # new function to be renamed later..
    my ( $gv, $fullname ) = @_;

    my $gvav = $gv->AV;
    return 'NULL' unless $gvav && $$gvav;

    if ( $fullname eq 'main::_' ) {
        $gvav = svref_2object( \@under );
    }

    # # rely on final replace to get the symbol name, it s fine
    # my $svsym = sprintf( "s\\_%x", $$gvsv );

    my $svsym = $gvav->save($fullname);
    if ( $fullname eq 'main::-' ) {    # fixme: can directly save these values
        init()->sadd( "AvFILLp(s\\_%x) = -1;", $$gvav );
        init()->sadd( "AvMAX(s\\_%x) = -1;",   $$gvav );
    }

    return $svsym;
}

sub save_gv_hv {                       # new function to be renamed later..
    my ( $gv, $fullname ) = @_;

    my $gvhv = $gv->HV;
    return 'NULL' unless $gvhv && $$gvhv;

    # Handle HV exceptions first...
    return 'NULL' if $fullname eq 'main::ENV';    # do not save %ENV

    debug( gv => "GV::save \%$fullname" );

    # skip static %Encode::Encoding since 5.20. GH #200. sv_upgrade cannot upgrade itself.
    # Let it be initialized by boot_Encode/Encode_XSEncodingm with exceptions.
    # GH #200 and t/testc.sh 75
    if ( $fullname eq 'Encode::Encoding' ) {
        debug( gv => "skip some %Encode::Encoding - XS initialized" );
        my %tmp_Encode_Encoding = %Encode::Encoding;
        %Encode::Encoding = ();    # but we need some non-XS encoding keys
        foreach my $k (qw(utf8 utf-8-strict Unicode Internal Guess)) {
            $Encode::Encoding{$k} = $tmp_Encode_Encoding{$k} if exists $tmp_Encode_Encoding{$k};
        }
        my $sym = $gvhv->save($fullname);

        #         init()->add("/* deferred some XS enc pointers for \%Encode::Encoding */");
        #         init()->sadd( "GvHV(%s) = s\\_%x;", $sym, $$gvhv );

        %Encode::Encoding = %tmp_Encode_Encoding;
        return $sym;
    }

    return $gvhv->save($fullname);
}

sub save_gv_cv {
    my ( $gv, $fullname, $gp_ix ) = @_;

    debug( gv => ".... save_gv_cv $fullname" );

    my $package = $gv->get_package();
    my $gvcv    = $gv->CV;
    if ( !$$gvcv ) {

        # STATIC_HV: We're not expanding AUTOLOAD and missing stuff.
        #debug( gv => "Empty CV $fullname, AUTOLOAD and try again" );
        #no strict 'refs';

        # Fix test 31, catch unreferenced AUTOLOAD. The downside:
        # It stores the whole optree and all its children.
        # Similar with test 39: re::is_regexp
        #svref_2object( \*{"$package\::AUTOLOAD"} )->save if $package and exists ${"$package\::"}{AUTOLOAD};
        #svref_2object( \*{"$package\::CLONE"} )->save    if $package and exists ${"$package\::"}{CLONE};
        #$gvcv = $gv->CV;    # try again

        return 'NULL';    # ??? really
    }

    return 'NULL' unless ref($gvcv) eq 'B::CV';
    return 'NULL' if ref( $gvcv->GV ) eq 'B::SPECIAL' or ref( $gvcv->GV->EGV ) eq 'B::SPECIAL';

    my $gvname = $gv->NAME();
    my $gp     = $gv->GP;

    my $cvsym = 'NULL';

    # Can't locate object method "EGV" via package "B::SPECIAL" at /usr/local/cpanel/3rdparty/perl/520/lib/perl5/cpanel_lib/i386-linux-64int/B/C/OverLoad/B/GV.pm line 450.
    {
        if ($gp) {
            $cvsym = $gvcv->save($fullname);
        }
        my $origname = $gv->cv_needs_import_after_bootstrap( $cvsym, $fullname );
        if ($origname) {
            debug( gv => "bootstrap CV $fullname using $origname\n" );
            init_bootstraplink()->sadd( 'gp_list[%d].gp_cv = GvCV( gv_fetchpv(%s, 0, SVt_PVCV) );', $gp_ix, cstring($origname) );
        }

    }

    return $cvsym;
}

sub cv_needs_import_after_bootstrap {
    my ( $gv, $cvsym, $fullname ) = @_;

    return 0 unless $cvsym && $cvsym =~ m{BOOTSTRAP_XS_\Q[[\E(.+?)\Q]]\E_XS_BOOTSTRAP};
    my $bootstrapped_xs_sub = $1;

    my $package  = $gv->CV->GV->STASH->NAME;    # is it the same than package earlier ??
    my $oname    = $gv->CV->GV->NAME;
    my $origname = $package . "::" . $oname;

    return '' if $origname =~ m/::__ANON__$/;    # How do we bootstrap __ANON__ XSUBs?

    my $ret = $fullname eq $origname ? '' : $origname;

    return $ret;
}

sub save_gv_format {
    my ( $gv, $fullname ) = @_;

    my $gvform = $gv->FORM;
    return 'NULL' unless $gvform && $$gvform;

    return $gvform->save($fullname);

    # init()->sadd( "GvFORM(%s) = (CV*)s\\_%x;", $sym, $$gvform );

    # return;
}

sub save_gv_io {
    my ( $gv, $fullname ) = @_;    # TODO: this one needs sym for now

    my $gvio = $gv->IO;
    return 'NULL' unless $$gvio;

    if ( $fullname =~ m/::DATA$/ ) {
        no strict 'refs';
        my $fh = *{$fullname}{IO};
        use strict 'refs';

        if ( $fh->opened ) {
            my @read_data = <$fh>;
            my $data = join '', @read_data;

            return $gvio->save_io_and_data( $fullname, $data );
        }

        # Houston we have a problem there ?
    }

    return ( $gvio->save($fullname), undef );
}

sub get_savefields {
    my ( $gv, $fullname ) = @_;

    my $gvname = $gv->FULLNAME;

    # default savefields
    my $all_fields = Save_HV | Save_AV | Save_SV | Save_CV | Save_FORM | Save_IO;
    my $savefields = 0;

    my $gp = $gv->GP;

    # some non-alphabetic globs require some parts to be saved
    # ( ex. %!, but not $! )
    if ( ref($gv) eq 'B::STASHGV' and $gvname !~ /::$/ ) {

        # https://code.google.com/archive/p/perl-compiler/issues/79 - Only save stashes for stashes.
        $savefields = 0;
    }
    elsif ( $fullname eq 'main::!' ) {    #Errno
        $savefields = Save_HV | Save_SV | Save_CV;
    }
    elsif ( $fullname =~ /^DynaLoader::dl_(require_symbols|resolve_using|librefs)$/ ) {    # no need to assign any SV/AV/HV to them (172)
        $savefields = Save_CV | Save_FORM | Save_IO;
    }
    elsif ( $fullname eq 'main::ENV' ) {
        $savefields = $all_fields ^ Save_HV;
    }
    elsif ( $fullname eq 'main::ARGV' ) {
        $savefields = $all_fields ^ Save_AV;
    }
    elsif ( $fullname =~ /^main::STD(IN|OUT|ERR)$/ ) {
        $savefields = Save_FORM | Save_IO;
    }
    elsif ( $fullname eq 'main::_' ) {
        $savefields = Save_AV | Save_SV;
    }
    elsif ( $fullname eq 'main::@' ) {
        $savefields = Save_SV;
    }
    elsif ( $gvname =~ /^main::[^A-Za-z]$/ ) {
        $savefields = Save_SV;
    }
    else {
        $savefields = $all_fields;
    }

    # avoid overly dynamic POSIX redefinition warnings: GH #335, #345
    if ( $fullname =~ m/^POSIX::M/ or $fullname eq 'attributes::bootstrap' ) {
        $savefields &= ~Save_CV;
    }

    my $is_gvgp    = $gv->isGV_with_GP;
    my $is_coresym = $gv->is_coresym();
    if ( !$is_gvgp or $is_coresym ) {
        $savefields &= ~Save_FORM;
        $savefields &= ~Save_IO;
    }

    $savefields |= Save_FILE if ( $is_gvgp and !$is_coresym );

    return $savefields;
}

sub savecv {
    my $gv      = shift;
    my $package = $gv->STASH->NAME;
    my $name    = $gv->NAME;
    my $cv      = $gv->CV;
    my $sv      = $gv->SV;
    my $av      = $gv->AV;
    my $hv      = $gv->HV;

    # We Should NEVER compile B::C packages so if we get here, it's a bug.
    # TODO: Currently breaks xtestc/0350.t and xtestc/0371.t if we make this a die.
    return if $package eq 'B::C';

    my $fullname = $package . "::" . $name;
    debug( gv => "Checking GV *%s 0x%x\n", cstring($fullname), ref $gv ? $$gv : 0 ) if verbose();

    # We may be looking at this package just because it is a branch in the
    # symbol table which is on the path to a package which we need to save
    # e.g. this is 'Getopt' and we need to save 'Getopt::Long'
    #
    return if ( $package ne 'main' and !is_package_used($package) );
    return if ( $package eq 'main'
        and $name =~ /^([^\w].*|_\<.*|INC|ARGV|SIG|ENV|BEGIN|main::|!)$/ );

    debug( gv => "GV::savecv - Used GV \*$fullname 0x%x", ref $gv ? $$gv : 0 );
    debug( gv => "... called from %s", 'B::C::Save'->can('stack_flat')->() );
    return unless ( $$cv || $$av || $$sv || $$hv || $gv->IO || $gv->FORM );
    if ( $$cv and $name eq 'bootstrap' and $cv->XSUB ) {

        #return $cv->save($fullname);
        debug( gv => "Skip XS \&$fullname 0x%x", ref $cv ? $$cv : 0 );
        return;
    }
    if (
        $$cv and B::C::in_static_core( $package, $name ) and ref($cv) eq 'B::CV'    # 5.8,4 issue32
        and $cv->XSUB
      ) {
        debug( gv => "Skip internal XS $fullname" );
        return;
    }

    # STATIC_HV: This code was removed because white listing doesn't really work with force_heavy any more.
    # What is done here has not been analyzed to see if we need to fix it.
    ## load utf8 and bytes on demand.
    #if ( my $newgv = force_heavy( $package, $fullname ) ) {
    #    $gv = $newgv;
    #}

    # XXX fails and should not be needed. The B::C part should be skipped 9 lines above, but be defensive
    return if $fullname eq 'B::walksymtable' or $fullname eq 'B::C::walksymtable';

    $B::C::dumped_package{$package} = 1 if !exists $B::C::dumped_package{$package} and $package !~ /::$/;
    debug( gv => "Saving GV \*$fullname 0x%x", ref $gv ? $$gv : 0 );
    $gv->save($fullname);
}

sub FULLNAME {
    my ($gv) = @_;

    my $stash = $gv->STASH;

    # B::SPECIAL means the stash is a NULL.
    my $stash_name = ref $stash eq 'B::SPECIAL' ? '' : $stash->NAME;

    my $name = $gv->NAME || '';

    return $name if !$stash_name;
    return $stash_name . '::' . $name;
}

1;
