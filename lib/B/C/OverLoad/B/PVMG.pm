package B::PVMG;

use strict;

use Config ();    # TODO: Removing this causes unit tests to fail in B::C ???
use B::C::Config;
use B qw/SVf_ROK SVf_READONLY HEf_SVKEY SVf_READONLY SVf_AMAGIC SVf_IsCOW cstring cchar SVp_POK svref_2object class/;
use B::C::Save qw/savepv/;
use B::C::Decimal qw/get_integer_value get_double_value/;
use B::C::File qw/init init_static_assignments svsect xpvmgsect magicsect init_vtables/;
use B::C::Helpers qw/read_utf8_string get_index/;

sub do_save {
    my ( $sv, $fullname ) = @_;

    my ( $savesym, $cur, $len, $pv, $static, $flags ) = B::PV::save_pv_or_rv( $sv, $fullname );
    if ($static) {    # 242: e.g. $1
        $static = 0;
        $len = $cur + 1 unless $len;
    }

    my $ivx = get_integer_value( $sv->IVX );    # XXX How to detect HEK* namehek?
    my $nvx = get_double_value( $sv->NVX );     # it cannot be xnv_u.xgv_stash ptr (BTW set by GvSTASH later)

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
        die("This code  used to call _patch_dlsym. The logic didn't make sense after the CV re-factor so it's been removed here.");
    }

    if ( $flags & SVf_ROK ) {          # sv => sv->RV cannot be initialized static.
        init()->sadd( "SvRV_set(&sv_list[%d], (SV*)%s);", svsect()->index + 1, $savesym )
          if $savesym ne '';
        $savesym = 'NULL';
        $static  = 1;
    }

    xpvmgsect()->comment("STASH, MAGIC, cur, len, xiv_u, xnv_u");
    my $xpvmg_ix = xpvmgsect()->sadd(
        "(HV*) %s, {%s}, %u, {%u}, {%s}, {%s}",
        $sv->save_magic_stash, $sv->save_magic($fullname), $cur, $len, $ivx, $nvx
    );

    my $sv_u = $savesym eq 'NULL' ? 0 : ".svu_pv=(char*) $savesym";
    my $sv_ix = svsect()->sadd(
        "&xpvmg_list[%d], %Lu, 0x%x, {%s}",
        $xpvmg_ix, $sv->REFCNT + 1, $flags, $sv_u
    );

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
    return '0' if ( !$sv->MAGICAL );

    my @mgchain    = $sv->MAGIC;
    my $last_magic = '0';
    foreach my $mg ( reverse @mgchain ) {    # reverse because we're assigning down the chain, not up.
        my $type = $mg->TYPE;
        my $ptr  = $mg->BCPTR;
        my $len  = $mg->LENGTH;

        exists $perl_magic_vtable_map->{$type} or die sprintf( "Unknown magic type '0x%s' / '%s' [check your mapping table dude]", unpack( 'H*', $type ), $type );
        my $vtable = $perl_magic_vtable_map->{$type};

        if ( defined $vtable and $vtable eq '0' ) {
            next;                            # STATIC HV: We need to know how to handle "extensions" or XS
        }

        ### view Perl_magic_freeovrld: contains a list of memory addresses to CVs...
        ###     the first call to Gv_AMG should recompute the cache
        ###     we are saving (( and other '(*' overload methods, like for example ("" for the str overload
        ### maybe we simply want to run Gv_AMG on the stash at init time
        next if $type eq 'c';

        # Save the object if there is one.
        my $obj = '0';
        if ( $type !~ /^[rDn]$/ ) {
            my $o = $mg->OBJ;
            $obj = $o->save($fullname) if ( ref $o ne 'SCALAR' );
        }

        my $ptrsv = '0';
        my $init_ptrsv;
        {    # was if $len == HEf_SVKEY

            # The pointer is an SV* ('s' sigelem e.g.)
            # XXX On 5.6 ptr might be a SCALAR ref to the PV, which was fixed later
            if ( !defined $ptr ) {
                $ptrsv = '0';
            }
            elsif ( ref($ptr) eq 'SCALAR' ) {

                # STATIC HV: We don't think anything happens here. Would like to test with a die();
                $init_ptrsv = "SvPVX(" . svref_2object($ptr)->save($fullname) . ")";
            }
            elsif ( ref $ptr ) {

                # Certain magic type actually point to a PMOP or a SVPV. We save them here.
                # NOTE: This is thanks to BCPTR which needs to backport to B.xs
                $ptrsv = ref $ptr =~ m/OP/ ? $ptr->save() : $ptr->save($fullname);
            }
            else {
                $ptrsv = cstring($ptr);    # Nico thinks everything will happen here.
            }
        }

        magicsect->comment('mg_moremagic, mg_virtual, mg_private, mg_type, mg_flags, mg_len, mg_obj, mg_ptr');

        my $last_magic_ix = magicsect->saddl(
            '(MAGIC*) %s'  => $last_magic,     # mg_moremagic
            '(MGVTBL*) %s' => '0',             # mg_virtual
            '%s'           => $mg->PRIVATE,    # mg_private
            '%s'           => cchar($type),    # mg_type
            '0x%x'         => $mg->FLAGS,      # mg_flags
            '%s'           => $len,            # mg_len
            '(SV*) %s'     => $obj,            # mg_obj
            '(char*) %s'   => $ptrsv,          # mg_ptr
        );
        $last_magic = sprintf( 'magic_list[%d]', $last_magic_ix );

        if ($init_ptrsv) {
            init_static_assignments()->sadd( q{%s.mg_ptr = (char*) %s;}, $last_magic, $init_ptrsv );
        }

        init_vtables()->sadd( '%s.mg_virtual = (MGVTBL*) &PL_vtbl_%s;', $last_magic, $vtable ) if $vtable;
        $last_magic = "&" . $last_magic;
    }

    return $last_magic;
}

sub save_magic_stash {
    my $sv = shift or die("save_magic_stash is a method call!");

    my $symbol = $sv->SvSTASH->save || return q{0};

    return q{0} if $symbol eq 'Nullsv';
    return q{0} if $symbol eq 'Nullhv';
    return "(HV*) $symbol";
}
1;
