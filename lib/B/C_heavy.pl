package B::C;
use strict;

BEGIN {
    require B::C::Flags;
    *Config = \%B::C::Flags::Config;
}

use B qw(minus_c sv_undef walkoptree walkoptree_slow main_root main_start peekop
  class cchar svref_2object compile_stats comppadlist hash
  init_av end_av opnumber cstring
  HEf_SVKEY SVf_POK SVf_ROK SVf_IOK SVf_NOK SVf_IVisUV SVf_READONLY);

BEGIN {
    @B::NV::ISA = 'B::IV';    # add IVX to nv. This fixes test 23 for Perl 5.8
    B->import(qw(regex_padav SVp_NOK SVp_IOK CVf_CONST CVf_ANON SVt_PVGV));
}

use B::C::File qw( init2 init0 init decl free
  heksect binopsect condopsect copsect padopsect listopsect logopsect
  opsect pmopsect pvopsect svopsect unopsect svsect xpvsect xpvavsect xpvhvsect xpvcvsect xpvivsect xpvuvsect
  xpvnvsect xpvmgsect xpvlvsect xrvsect xpvbmsect xpviosect padlistsect loopsect sharedhe
);

use B::C::Packages qw/is_package_used mark_package_unused mark_package_used mark_package_removed get_all_packages_used/;

our %Regexp;
our %isa_cache;

our ( $package_pv, @package_pv );    # global stash for methods since 5.13

# FIXME: this part can now be dynamic
# exclude all not B::C:: prefixed subs
# used in CV
our %all_bc_subs = map { $_ => 1 } qw(B::AV::save B::BINOP::save B::BM::save B::COP::save B::CV::save
  B::FAKEOP::fake_ppaddr B::FAKEOP::flags B::FAKEOP::new B::FAKEOP::next
  B::FAKEOP::ppaddr B::FAKEOP::private B::FAKEOP::save B::FAKEOP::sibling
  B::FAKEOP::targ B::FAKEOP::type B::GV::save B::GV::savecv B::HV::save
  B::IO::save B::IO::save_data B::IV::save B::LISTOP::save B::LOGOP::save
  B::LOOP::save B::NULL::save B::NV::save B::OBJECT::save
  B::OP::_save_common B::OP::fake_ppaddr B::OP::isa B::OP::save
  B::PADLIST::save B::PADOP::save B::PMOP::save B::PV::save B::PVIV::save
  B::PVLV::save B::PVMG::save B::PVMG::save_magic B::PVNV::save B::PVOP::save
  B::REGEXP::save B::RV::save B::SPECIAL::save B::SPECIAL::savecv
  B::SV::save B::SVOP::save B::UNOP::save B::UV::save B::REGEXP::EXTFLAGS);

# track all internally used packages. all other may not be deleted automatically
# - hidden methods
# uses now @B::C::Flags::deps
our %all_bc_deps = map { $_ => 1 } @B::C::Flags::deps;

# Look this up here so we can do just a number compare
# rather than looking up the name of every BASEOP in B::OP
# maybe use contant
our $OP_THREADSV = opnumber('threadsv');
our $OP_DBMOPEN  = opnumber('dbmopen');
our $OP_FORMLINE = opnumber('formline');
our $OP_UCFIRST  = opnumber('ucfirst');

# This the Carp free workaround for DynaLoader::bootstrap
{
    # Scoped no warnings without loading the module.
    local $^W;
    BEGIN { ${^WARNING_BITS} = 0; }
    *DynaLoader::croak = sub { die @_ }
}

{
    my $caller = original_caller();
    if ( $caller eq 'O' or $caller eq 'Od' ) {
        require XSLoader;
        XSLoader::load('B::C');    # for r-magic and for utf8-keyed B::HV->ARRAY
    }
}

sub walk_and_save_optree {
    my ( $name, $root, $start ) = @_;
    if ($root) {

        # B.xs: walkoptree does more, reifying refs. rebless or recreating it.
        verbose() ? walkoptree_slow( $root, "save" ) : walkoptree( $root, "save" );
    }
    return objsym($start);
}

# Fixes bug #307: use foreach, not each
# each is not safe to use (at all). walksymtable is called recursively which might add
# symbols to the stash, which might cause re-ordered rehashes, which will fool the hash
# iterator, leading to missing symbols in the binary.
# Old perl5 bug: The iterator should really be stored in the op, not the hash.
sub walksymtable {
    my ( $symref, $method, $recurse, $prefix ) = @_;
    my ( $sym, $ref, $fullname );
    $prefix = '' unless defined $prefix;

    # If load_utf8_heavy doesn't happen before we walk utf8:: (when utf8_heavy has already been called) then the stored CV for utf8::SWASHNEW could be wrong.
    load_utf8_heavy() if ( $prefix eq 'utf8::' && defined $symref->{'SWASHNEW'} );

    my @list = sort {

        # we want these symbols to be saved last to avoid incomplete saves
        # +/- reverse is to defer + - to fix Tie::Hash::NamedCapturespecial cases. GH #247
        # _loose_name redefined from utf8_heavy.pl
        # re can be loaded by utf8_heavy
        foreach my $v (qw{- + re:: utf8:: bytes::}) {
            $a eq $v and return 1;
            $b eq $v and return -1;
        }

        # reverse order for now to preserve original behavior before improved patch
        $b cmp $a
    } keys %$symref;

    # reverse is to defer + - to fix Tie::Hash::NamedCapturespecial cases. GH #247
    foreach my $sym (@list) {
        no strict 'refs';
        $ref      = $symref->{$sym};
        $fullname = "*main::" . $prefix . $sym;
        if ( $sym =~ /::$/ ) {
            $sym = $prefix . $sym;
            if ( svref_2object( \*$sym )->NAME ne "main::" && $sym ne "<none>::" && &$recurse($sym) ) {
                walksymtable( \%$fullname, $method, $recurse, $sym );
            }
        }
        else {
            svref_2object( \*$fullname )->$method();
        }
    }
}

sub saveoptree { goto &walk_and_save_optree }

sub enable_option_debug {
    my $arg = shift;

    $arg =~ s{^=+}{};
    if ( B::C::Config::Debug::enable_debug_level($arg) ) {
        WARN("Enable debug mode: $arg");
        next;
    }
    foreach my $arg ( split( //, $arg ) ) {
        next if B::C::Config::Debug::enable_debug_level($arg);
        if ( $arg eq "o" ) {
            B::C::Config::Debug::enabe_verbose();
            B->debug(1);
        }
        elsif ( $arg eq "F" ) {
            B::C::Config::Debug::enable_debug_level('flags');
        }
        elsif ( $arg eq "r" ) {
            B::C::Config::Debug::enable_debug_level('runtime');
            $SIG{__WARN__} = sub {
                WARN(@_);
                my $s = join( " ", @_ );
                chomp $s;
                init()->add( "/* " . $s . " */" ) if init();
            };
        }
        else {
            WARN("ignoring unknown debug option: $arg");
        }
    }
}

sub svop_name {
    my $op = shift;
    my $cv = shift;
    my $sv;
    if ( $op->can('name') and $op->name eq 'padsv' ) {
        return padop_name( $op, $cv );
    }
    else {
        if ( !$op->can("sv") ) {
            if ( ref($op) eq 'B::PMOP' and $op->pmreplroot->can("sv") ) {
                $sv = $op->pmreplroot->sv;
            }
            else {
                $sv = $op->first->sv
                  unless $op->flags & 4
                  or ( $op->name eq 'const' and $op->flags & 34 )
                  or $op->first->can("sv");
            }
        }
        else {
            $sv = $op->sv;
        }
        if ( $sv and $$sv ) {
            if ( $sv->FLAGS & SVf_ROK ) {
                return '' if $sv->isa("B::NULL");
                my $rv = $sv->RV;
                if ( $rv->isa("B::PVGV") ) {
                    my $o = $rv->IO;
                    return $o->STASH->NAME if $$o;
                }
                return '' if $rv->isa("B::PVMG");
                return $rv->STASH->NAME;
            }
            else {
                if ( $op->name eq 'gvsv' or $op->name eq 'gv' ) {
                    return $sv->STASH->NAME . '::' . $sv->NAME;
                }

                return
                    $sv->can('STASH') ? $sv->STASH->NAME
                  : $sv->can('NAME')  ? $sv->NAME
                  :                     $sv->PV;
            }
        }
    }
}

# return the next COP for file and line info
sub nextcop {
    my $op = shift;
    while ( $op and ref($op) ne 'B::COP' and ref($op) ne 'B::NULL' ) { $op = $op->next; }
    return ( $op and ref($op) eq 'B::COP' ) ? $op : undef;
}


sub IsCOW {
    return ( ref $_[0] && $_[0]->can('FLAGS') && $_[0]->FLAGS & 0x10000000 );    # since 5.22
}

sub IsCOW_hek {
    return IsCOW( $_[0] ) && !$_[0]->LEN;
}


# This pair is needed because B::FAKEOP::save doesn't scalar dereference
# $op->next and $op->sibling

# For 5.8:
# Current workaround/fix for op_free() trying to free statically
# defined OPs is to set op_seq = -1 and check for that in op_free().
# Instead of hardwiring -1 in place of $op->seq, we use $op_seq
# so that it can be changed back easily if necessary. In fact, to
# stop compilers from moaning about a U16 being initialised with an
# uncast -1 (the printf format is %d so we can't tweak it), we have
# to "know" that op_seq is a U16 and use 65535. Ugh.

# For 5.9 the hard coded text is the values for op_opt and op_static in each
# op.  The value of op_opt is irrelevant, and the value of op_static needs to
# be 1 to tell op_free that this is a statically defined op and that is
# shouldn't be freed.

# For 5.10 op_seq = -1 is gone, the temp. op_static also, but we
# have something better, we can set op_latefree to 1, which frees the children
# (e.g. savepvn), but not the static op.

# 5.8: U16 op_seq;
# 5.9.4: unsigned op_opt:1; unsigned op_static:1; unsigned op_spare:5;
# 5.10: unsigned op_opt:1; unsigned op_latefree:1; unsigned op_latefreed:1; unsigned op_attached:1; unsigned op_spare:3;
# 5.18: unsigned op_opt:1; unsigned op_slabbed:1; unsigned op_savefree:1; unsigned op_static:1; unsigned op_spare:3;
# 5.19: unsigned op_opt:1; unsigned op_slabbed:1; unsigned op_savefree:1; unsigned op_static:1; unsigned op_folded:1; unsigned op_spare:2;
# 5.21.2: unsigned op_opt:1; unsigned op_slabbed:1; unsigned op_savefree:1; unsigned op_static:1; unsigned op_folded:1; unsigned op_lastsib:1; unsigned op_spare:1;

# fixme only use opsect common
{
    # should use a static variable
    # only for $] < 5.021002
    my $opsect_common = "next, sibling, ppaddr, " . ( MAD() ? "madprop, " : "" ) . "targ, type, " . "opt, slabbed, savefree, static, folded, moresib, spare" . ", flags, private";

    sub opsect_common {
        return $opsect_common;
    }

}

# save alternate ops if defined, and also add labels (needed for B::CC)
sub do_labels ($$@) {
    my $op    = shift;
    my $level = shift;

    for my $m (@_) {
        no strict 'refs';
        my $mo = $op->$m if $m;
        if ( $mo and $$mo ) {
            $mo->save($level)
              if $m ne 'first'
              or ( $op->flags & 4
                and !( $op->name eq 'const' and $op->flags & 64 ) );    #OPpCONST_BARE has no first
        }
    }
}

sub get_isa ($) {
    no strict 'refs';

    my $name = shift;
    if ( is_using_mro() ) {    # mro.xs loaded. c3 or dfs
        return @{ mro::get_linear_isa($name) };
    }

    # dfs only, without loading mro
    return @{ B::C::get_linear_isa($name) };
}


my @_v = Internals::V();
sub __ANON__::_V { @_v }

sub save_object {
    foreach my $sv (@_) {
        svref_2object($sv)->save;
    }
}


# XXX issue 64, empty @ISA if a package has no subs. in Bytecode ok
sub try_isa {
    my ( $cvstashname, $cvname ) = @_;
    return 0 unless defined $cvstashname;
    if ( my $found = $isa_cache{"$cvstashname\::$cvname"} ) {
        return $found;
    }
    no strict 'refs';

    # XXX theoretically a valid shortcut. In reality it fails when $cvstashname is not loaded.
    # return 0 unless $cvstashname->can($cvname);
    my @isa = get_isa($cvstashname);
    debug(
        cv => "No definition for sub %s::%s. Try \@%s::ISA=(%s)",
        $cvstashname, $cvname, $cvstashname, join( ",", @isa )
    );
    for (@isa) {    # global @ISA or in pad
        next if $_ eq $cvstashname;
        debug( cv => "Try &%s::%s", $_, $cvname );
        if ( defined( &{ $_ . '::' . $cvname } ) ) {
            if ( exists( ${ $cvstashname . '::' }{ISA} ) ) {
                svref_2object( \@{ $cvstashname . '::ISA' } )->save("$cvstashname\::ISA");
            }
            $isa_cache{"$cvstashname\::$cvname"} = $_;
            mark_package( $_, 1 );    # force
            return $_;
        }
        else {
            $isa_cache{"$_\::$cvname"} = 0;
            if ( get_isa($_) ) {
                my $parent = try_isa( $_, $cvname );
                if ($parent) {
                    $isa_cache{"$_\::$cvname"}           = $parent;
                    $isa_cache{"$cvstashname\::$cvname"} = $parent;
                    debug( gv => "Found &%s::%s", $parent, $cvname );
                    if ( exists( ${ $parent . '::' }{ISA} ) ) {
                        debug( pkg => "save \@$parent\::ISA" );
                        svref_2object( \@{ $parent . '::ISA' } )->save("$parent\::ISA");
                    }
                    if ( exists( ${ $_ . '::' }{ISA} ) ) {
                        debug( pkg => "save \@$_\::ISA\n" );
                        svref_2object( \@{ $_ . '::ISA' } )->save("$_\::ISA");
                    }
                    return $parent;
                }
            }
        }
    }
    return 0;    # not found
}

# used by B::OBJECT
sub add_to_isa_cache {
    my ( $k, $v ) = @_;
    die unless defined $k;

    $isa_cache{$k} = $v;
    return;
}

# Do not delete/ignore packages which were brought in from the script,
# i.e. not defined in B::C or O. Just to be on the safe side.
sub can_delete {
    my $pkg = shift;
    if ( exists $all_bc_deps{$pkg} ) { return 1 }
    return undef;
}

# 1. called from method_named, so hashp should be defined
# 2. called from svop before method_named to cache the $package_pv
sub svop_or_padop_pv {
    my $op = shift;
    my $sv;
    if ( !$op->can("sv") ) {
        if ( $op->can('name') and $op->name eq 'padsv' ) {
            my @c   = comppadlist->ARRAY;
            my @pad = $c[1]->ARRAY;
            return $pad[ $op->targ ]->PV if $pad[ $op->targ ] and $pad[ $op->targ ]->can("PV");

            # This might fail with B::NULL (optimized ex-const pv) entries in the pad.
        }

        # $op->can('pmreplroot') fails for 5.14
        if ( ref($op) eq 'B::PMOP' and $op->pmreplroot->can("sv") ) {
            $sv = $op->pmreplroot->sv;
        }
        else {
            return $package_pv unless $op->flags & 4;

            # op->first is disallowed for !KIDS and OPpCONST_BARE
            return $package_pv if $op->name eq 'const' and $op->flags & 64;
            return $package_pv unless $op->first->can("sv");
            $sv = $op->first->sv;
        }
    }
    else {
        $sv = $op->sv;
    }

    # XXX see SvSHARED_HEK_FROM_PV for the stash in S_method_common pp_hot.c
    # In this hash the CV is stored directly
    if ( $sv and $$sv ) {

        return $sv->PV if $sv->can("PV");
        if ( ref($sv) eq "B::SPECIAL" ) {    # DateTime::TimeZone
                                             # XXX null -> method_named
            debug( gv => "NYI S_method_common op->sv==B::SPECIAL, keep $package_pv" );
            return $package_pv;
        }
        if ( $sv->FLAGS & SVf_ROK ) {
            goto missing if $sv->isa("B::NULL");
            my $rv = $sv->RV;
            if ( $rv->isa("B::PVGV") ) {
                my $o = $rv->IO;
                return $o->STASH->NAME if $$o;
            }
            goto missing if $rv->isa("B::PVMG");
            return $rv->STASH->NAME;
        }
        else {
          missing:
            if ( $op->name ne 'method_named' ) {

                # Called from first const/padsv before method_named. no magic pv string, so a method arg.
                # The first const pv as method_named arg is always the $package_pv.
                return $package_pv;
            }
            elsif ( $sv->isa("B::IV") ) {
                WARN(
                    sprintf(
                        "Experimentally try method_cv(sv=$sv,$package_pv) flags=0x%x",
                        $sv->FLAGS
                    )
                );

                # QUESTION: really, how can we test it ?
                # XXX untested!
                return svref_2object( method_cv( $$sv, $package_pv ) );
            }
        }
    }
    else {
        my @c   = comppadlist->ARRAY;
        my @pad = $c[1]->ARRAY;
        return $pad[ $op->targ ]->PV if $pad[ $op->targ ] and $pad[ $op->targ ]->can("PV");
    }
}

sub inc_packname {
    my $package = shift;

    # See below at the reverse packname_inc: utf8 => utf8.pm + utf8_heavy.pl
    $package =~ s/\:\:/\//g;
    $package .= '.pm';
    return $package;
}

sub packname_inc {
    my $package = shift;
    $package =~ s/\//::/g;
    if ( $package =~ /^(Config_git\.pl|Config_heavy.pl)$/ ) {
        return 'Config';
    }
    if ( $package eq 'utf8_heavy.pl' ) {
        return 'utf8';
    }
    $package =~ s/\.p[lm]$//;
    return $package;
}

1;