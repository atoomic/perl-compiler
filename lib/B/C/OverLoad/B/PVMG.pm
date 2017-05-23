package B::PVMG;

use strict;

use Config ();    # TODO: Removing this causes unit tests to fail in B::C ???
use B::C::Config;
use B qw/SVf_ROK SVf_READONLY HEf_SVKEY SVf_READONLY SVf_AMAGIC SVf_IsCOW cstring cchar SVp_POK svref_2object class/;
use B::C::Save qw/savepvn savepv savestashpv/;
use B::C::Decimal qw/get_integer_value get_double_value/;
use B::C::File qw/init init1 init2 init_static_assignments svsect xpvmgsect xpvsect pmopsect assign_hekkey2pv magicsect init_vtables/;
use B::C::Helpers qw/read_utf8_string is_shared_hek get_index/;
use B::C::Save::Hek qw/save_shared_he/;

sub do_save {
    my ( $sv, $fullname ) = @_;

    my ( $savesym, $cur, $len, $pv, $static, $flags ) = B::PV::save_pv_or_rv( $sv, $fullname );
    if ($static) {    # 242: e.g. $1
        $static = 0;
        $len = $cur + 1 unless $len;
    }

    my ( $ivx, $nvx );

    # since 5.11 REGEXP isa PVMG, but has no IVX and NVX methods
    if ( ref($sv) eq 'B::REGEXP' ) {
        return B::REGEXP::save( $sv, $fullname );
    }
    else {
        $ivx = get_integer_value( $sv->IVX );    # XXX How to detect HEK* namehek?
        $nvx = get_double_value( $sv->NVX );     # it cannot be xnv_u.xgv_stash ptr (BTW set by GvSTASH later)

        # See #305 Encode::XS: XS objects are often stored as SvIV(SvRV(obj)). The real
        # address needs to be patched after the XS object is initialized.
        # But how detect them properly?
        # Detect ptr to extern symbol in shared library and remap it in init2
        # Safe and mandatory currently only Net-DNS-0.67 - 0.74.
        # svop const or pad OBJECT,IOK
        if (
            # fixme simply the or logic
            ( ( $fullname and $fullname =~ /^svop const|^padop|^Encode::Encoding| :pad\[1\]/ ) )
            and $ivx > LOWEST_IMAGEBASE    # some crazy heuristic for a sharedlibrary ptr in .data (> image_base)
            and ref( $sv->SvSTASH ) ne 'B::SPECIAL'
          ) {
            $ivx = _patch_dlsym( $sv, $fullname, $ivx );
        }
    }

    if ( $flags & SVf_ROK ) {              # sv => sv->RV cannot be initialized static.
        init()->sadd( "SvRV_set(&sv_list[%d], (SV*)%s);", svsect()->index + 1, $savesym )
          if $savesym ne '';
        $savesym = 'NULL';
        $static  = 1;
    }

    my $stash = $sv->SvSTASH->save;
    $stash = q{Nullhv} if $stash eq 'NULL';

    xpvmgsect()->comment("STASH, MAGIC, cur, len, xiv_u, xnv_u");
    my $xpvmg_ix = xpvmgsect()->sadd(
        "(HV*) %s, %s, %u, {%u}, {%s}, {%s}",
        $stash, $sv->save_magic($fullname), $cur, $len, $ivx, $nvx
    );

    my $sv_u = $savesym eq 'NULL' ? 0 : ".svu_pv=(char*) $savesym";
    my $sv_ix = svsect()->sadd(
        "&xpvmg_list[%d], %Lu, 0x%x, {%s}",
        $xpvmg_ix, $sv->REFCNT + 1, $flags, $sv_u
    );
    svsect()->debug( $fullname, $sv );

    if ( defined($pv) and !$static ) {
        my $shared_hek = is_shared_hek($sv);
        if ($shared_hek) {
            my $hek = save_shared_he( $pv, $fullname );
            assign_hekkey2pv()->add( $sv_ix, get_index($hek) ) if $hek ne 'NULL';
        }
    }

    return sprintf( q{&sv_list[%d]}, $sv_ix );
}

# https://metacpan.org/pod/distribution/perl/pod/perlguts.pod
my $perl_magic_vtable_map = {

    # There is no corresponding PL_vtbl_ for these entries.
    '%' => undef,    # Extra data for restricted hashes - PERL_MAGIC_rhash
    ':' => undef,    # Extra data for symbol tables - toke.c - PERL_MAGIC_symtab
    'L' => undef,    # Debugger %_<filename - PERL_MAGIC_dbfile
    'S' => undef,    # %SIG hash - PERL_MAGIC_sig
    'V' => undef,    # SV was vstring literal - PERL_MAGIC_vstring

    # Die if we get these? Strip the magic and hope bootstrap puts them back??
    'u' => 0,        # Reserved for use by extensions - PERL_MAGIC_uvar_elem
    '~' => 0,        # Available for use by extensions - PERL_MAGIC_ext

    # All of these are PL_vtbl_$value so easily assigned on startup.
    chr(0) => 'sv',               # Special scalar variable ( \0 )
    '#'    => 'arylen',           # Array length ($#ary)
    '*'    => 'debugvar',         # $DB::single, signal, trace vars
    '.'    => 'pos',              # pos() lvalue
    '<'    => 'backref',          # For weak ref data
    '@'    => 'arylen_p',         # To move arylen out of XPVAV
    'B'    => 'bm',               # Boyer-Moore (fast string search)
    'c'    => 'ovrld',            # Holds overload table (AMT) on stash - PERL_MAGIC_overload_table
    'D'    => 'regdata',          # Regex match position data (@+ and @- vars)
    'd'    => 'regdatum',         # Regex match position data element
    'E'    => 'env',              # %ENV hash
    'e'    => 'envelem',          # %ENV hash element
    'f'    => 'fm',               # Formline ('compiled' format)
    'g'    => 'mglob',            # m//g target - PERL_MAGIC_regex_global
    'H'    => 'hints',            # %^H hash
    'h'    => 'hintselem',        # %^H hash element
    'I'    => 'isa',              # @ISA array
    'i'    => 'isaelem',          # @ISA array element
    'k'    => 'nkeys',            # scalar(keys()) lvalue
    'l'    => 'dbline',           # Debugger %_<filename element
    'N'    => 'shared',           # Shared between threads
    'n'    => 'shared_scalar',    # Shared between threads
    'o'    => 'collxfrm',         # Locale transformation
    'P'    => 'pack',             # Tied array or hash - PERL_MAGIC_tied
    'p'    => 'packelem',         # Tied array or hash element - PERL_MAGIC_tiedelem
    'q'    => 'packelem',         # Tied scalar or handle - PERL_MAGIC_tiedscalar
    'r'    => 'regexp',           # Precompiled qr// regex - PERL_MAGIC_qr
    's'    => 'sigelem',          # %SIG hash element
    't'    => 'taint',            # Taintedness
    'U'    => 'uvar',             # Available for use by extensions
    'v'    => 'vec',              # vec() lvalue
    'w'    => 'utf8',             # Cached UTF-8 information
    'x'    => 'substr',           # substr() lvalue
    'y'    => 'defelem',          # Shadow "foreach" iterator variable smart parameter vivification
    '\\'   => 'lvref',            # Lvalue reference constructor
    ']'    => 'checkcall',        # Inlining/mutation of call to this CV
};

sub save_magic {
    my ( $sv, $fullname ) = @_;
    my $sv_flags = $sv->FLAGS;
    my $pkg;

    # Protect our SVs against non-magic or SvPAD_OUR. Fixes tests 16 and 14 + 23
    return 'NULL' if ( !$sv->MAGICAL );

    my @mgchain    = $sv->MAGIC;
    my $last_magic = 'NULL';
    foreach my $mg ( reverse @mgchain ) {    # reverse because we're assigning down the chain, not up.
        my $type = $mg->TYPE;
        my $ptr  = $mg->PTR;
        my $len  = $mg->LENGTH;

        exists $perl_magic_vtable_map->{$type} or die sprintf( "Unknown magic type '0x%s' / '%s' [check your mapping table dude]", unpack( 'H*', $type ), $type );
        my $vtable = $perl_magic_vtable_map->{$type};

        if ( defined $vtable and $vtable eq '0' ) {
            next;                            # STATIC HV: We need to know how to handle "extensions" or XS
        }

        # Save the object if there is one.
        my $obj = 'NULL';
        if ( $type !~ /^[rDn]$/ ) {
            my $o = $mg->OBJ;
            $obj = $o->save($fullname) if ( ref $o ne 'SCALAR' );
        }

        my $ptrsv = 'NULL';
        {                                    # was if $len == HEf_SVKEY

            # The pointer is an SV* ('s' sigelem e.g.)
            # XXX On 5.6 ptr might be a SCALAR ref to the PV, which was fixed later
            if ( !defined $ptr ) {
                $ptrsv = 'NULL';
            }
            elsif ( ref($ptr) eq 'SCALAR' ) {

                # STATIC HV: We don't think anything happens here. Would like to test with a die();
                $ptrsv = "SvPVX(" . svref_2object($ptr)->save($fullname) . ")";
            }
            elsif ( ref $ptr ) {

                # STATIC HV: We don't think anything happens here. Would like to test with a die();
                $ptrsv = "SvPVX(" . $ptr->save($fullname) . ")";
            }
            else {
                $ptrsv = cstring($ptr);    # Nico thinks everything will happen here.
            }
        }

        magicsect->comment('mg_moremagic, mg_virtual, mg_private, mg_type, mg_flags, mg_len, mg_obj, mg_ptr');
        my $last_magic_ix = magicsect->sadd( " (MAGIC*) %s, (MGVTBL*) %s, %s, %s, %d, %s, (SV*) %s, %s", $last_magic, 'NULL', $mg->PRIVATE, cchar($type), $mg->FLAGS, $len, $obj, $ptrsv );
        $last_magic = sprintf( 'magic_list[%d]', $last_magic_ix );

        init_vtables()->sadd( '%s.mg_virtual = (MGVTBL*) &PL_vtbl_%s;', $last_magic, $vtable ) if $vtable;
        $last_magic = "&" . $last_magic;
    }

    return $last_magic;
}

# TODO: This was added to PVMG because we thought it was only used in this op but
# as of 5.18, it's used in B::CV::save
sub _patch_dlsym {
    my ( $sv, $fullname, $ivx ) = @_;
    my $pkg = '';
    if ( ref($sv) eq 'B::PVMG' ) {
        my $stash = $sv->SvSTASH;
        $pkg = $stash->can('NAME') ? $stash->NAME : '';
    }
    my $name = $sv->FLAGS & SVp_POK() ? $sv->PVX : "";
    my $ivxhex = sprintf( "0x%x", $ivx );

    # lazy load encode after walking the optree

    if ( $pkg eq 'Encode::XS' ) {
        if ( $fullname eq 'Encode::Encoding{iso-8859-1}' ) {
            $name = "iso8859_1_encoding";
        }
        elsif ( $fullname eq 'Encode::Encoding{null}' ) {
            $name = "null_encoding";
        }
        elsif ( $fullname eq 'Encode::Encoding{ascii-ctrl}' ) {
            $name = "ascii_ctrl_encoding";
        }
        elsif ( $fullname eq 'Encode::Encoding{ascii}' ) {
            $name = "ascii_encoding";
        }

        $pkg = 'Encode';
        if ( $name and $name =~ /^(ascii|ascii_ctrl|iso8859_1|null)/ ) {    # STATIC_HV: Dead code.
            my $enc = Encode::find_encoding($name);
            $name .= "_encoding" unless $name =~ /_encoding$/;
            $name =~ s/-/_/g;
            verbose("$pkg $Encode::VERSION with remap support for $name (find 1)");
        }
        else {
            for my $n ( Encode::encodings() ) {                             # >=5.16 constsub without name
                my $enc = Encode::find_encoding($n);
                if ( $enc and ref($enc) ne 'Encode::XS' ) {                 # resolve alias such as Encode::JP::JIS7=HASH(0x292a9d0)
                    $pkg = ref($enc);
                    $pkg =~ s/^(Encode::\w+)(::.*)/$1/;                     # collapse to the @dl_module name
                    $enc = Encode->find_alias($n);
                }
                if ( $enc and ref($enc) eq 'Encode::XS' and $sv->IVX == $$enc ) {
                    $name = $n;
                    $name =~ s/-/_/g;
                    $name .= "_encoding" if $name !~ /_encoding$/;

                    if ( $pkg ne 'Encode' ) {
                        verbose( "saving $pkg" . "::bootstrap" );           # STATIC_HV: Dead code.
                        svref_2object( \&{"$pkg\::bootstrap"} )->save;
                    }
                    last;
                }
            }
            if ($name) {
                verbose("$pkg $Encode::VERSION remap found for constant $name");
            }
            else {
                verbose("Warning: Possible missing remap for compile-time XS symbol in $pkg $fullname $ivxhex [#305]");
            }
        }
    }

    # Encode-2.59 uses a different name without _encoding
    elsif ( 'Encode'->can('find_encoding') && Encode::find_encoding($name) ) {
        my $enc = Encode::find_encoding($name);
        $pkg = ref($enc) if ref($enc) ne 'Encode::XS';

        $name .= "_encoding";
        $name =~ s/-/_/g;
        $pkg = 'Encode' unless $pkg;
        verbose("$pkg $Encode::VERSION with remap support for $name (find 2)");
    }

    # now that is a weak heuristic, which misses #305
    elsif ( defined($Net::DNS::VERSION)
        and $Net::DNS::VERSION =~ /^0\.(6[789]|7[1234])/ ) {
        if ( $fullname eq 'svop const' ) {
            $name = "ascii_encoding";
            $pkg = 'Encode' unless $pkg;
            WARN("Warning: Patch Net::DNS external XS symbol $pkg\::$name $ivxhex [RT #94069]");
        }
    }
    elsif ( $pkg eq 'Net::LibIDN' ) {
        $name = "idn_to_ascii";    # ??
    }

    # new API (only Encode so far)
    if ( $pkg and $name and $name =~ /^[a-zA-Z_0-9-]+$/ ) {    # valid symbol name
        verbose("Remap IOK|POK $pkg with $name");
        _save_remap( $pkg, $pkg, $name, $ivxhex, 0 );
        $ivx = "0UL /* $ivxhex => $name */";
    }
    else {
        WARN("Warning: Possible missing remap for compile-time XS symbol in $pkg $fullname $ivx [#305]");
    }
    return $ivx;
}

sub _save_remap {
    my ( $key, $pkg, $name, $ivx, $mandatory ) = @_;
    my $id = xpvmgsect()->index + 1;

    #my $svid = svsect()->index + 1;
    verbose("init remap for ${key}: $name $ivx in xpvmg_list[$id]");
    my $props = { NAME => $name, ID => $id, MANDATORY => $mandatory };
    $B::C::init2_remap{$key}{MG} = [] unless $B::C::init2_remap{$key}{'MG'};
    push @{ $B::C::init2_remap{$key}{MG} }, $props;

    return;
}

sub _savere {
    my $re = shift;
    my $flags = shift || 0;
    my $sym;
    my $pv = $re;
    my ( $is_utf8, $cur ) = read_utf8_string($pv);
    my $len = 0;    # static buffer

    # TODO: add a die and see if it s triggered
    # QUESTION: this code looks dead
    #   at least not triggered by the core unit tests

    my $refcnt = 1;    # ???? WTF

    my $xpv_ix = xpvsect()->sadd( "Nullhv, {0}, %u, {.xpvlenu_len=%u}", $cur, $len );    # 0 or $len ?
    my $sv_ix = svsect()->sadd( "&xpv_list[%d], %d, %x, {.svu_pv=(char*)%s}", $xpv_ix, $refcnt, 0x4405, savepv($pv) );
    $sym = sprintf( "&sv_list[%d]", $sv_ix );

    return ( $sym, $cur );
}

1;
