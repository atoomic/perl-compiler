#      C.pm
#
#      Copyright (c) 1996, 1997, 1998 Malcolm Beattie
#      Copyright (c) 2008, 2009, 2010, 2011 Reini Urban
#      Copyright (c) 2010 Nick Koston
#      Copyright (c) 2011, 2012, 2013, 2014, 2015 cPanel Inc
#
#      You may distribute under the terms of either the GNU General Public
#      License or the Artistic License, as specified in the README file.
#

package B::C;
use strict;

# From C.pm
our %Config;
our ( $VERSION, $caller, $nullop_count, $unresolved_count, $gv_index, $settings );
our ( @ISA, @EXPORT_OK );
our $const_strings = 1;    # TODO: This var needs to go away.

BEGIN {
    use B::C::Flags ();
    *Config = \%B::C::Flags::Config;
}

use B::Flags;
use B::C::Config;          # import everything
use B::C::Debug ();        # used for setting debug levels from cmdline

use B::C::File qw( init2 init1 init0 init decl free
  heksect binopsect condopsect copsect padopsect listopsect logopsect magicsect
  opsect pmopsect pvopsect svopsect unopsect svsect xpvsect xpvavsect xpvhvsect xpvcvsect xpvivsect xpvuvsect
  xpvnvsect xpvmgsect xpvlvsect xrvsect xpvbmsect xpviosect padlistsect loopsect sharedhe init_stash

  init_COREbootstraplink init_bootstraplink
);
use B::C::Helpers::Symtable qw(objsym savesym);

use Exporter ();
use Errno    ();           #needed since 5.14
our %Regexp;

# Caller was populated in C.pm
BEGIN {
    if ( $caller eq 'O' or $caller eq 'Od' ) {
        require XSLoader;
        no warnings;
        XSLoader::load('B::C');
    }
}

# for 5.6.[01] better use the native B::C
# but 5.6.2 works fine
use B qw(minus_c sv_undef walkoptree walkoptree_slow main_root main_start peekop
  class cchar svref_2object compile_stats comppadlist hash
  init_av end_av opnumber cstring
  HEf_SVKEY SVf_POK SVf_ROK SVf_IOK SVf_NOK SVf_IVisUV SVf_READONLY SVf_PROTECT);

BEGIN {
    @B::NV::ISA = 'B::IV';    # add IVX to nv. This fixes test 23 for Perl 5.8
    B->import(qw(regex_padav SVp_NOK SVp_IOK CVf_CONST CVf_ANON SVt_PVGV));
}

# this is crazyness.... and just working around a program which blacklist Carp.pm - view xtestc/0235.t
BEGIN {
    # rather than updating %INC and force Carp to being loaded,
    #   just make sure that croak is defined so we can load IO::Seekable
    # STATIC_HV: Altering the stash by loading modules after the white list has been established can lead to
    # problems. Ideally this code should be removed in favor of a better solution.
    local *Carp::croak = sub { die "Carp is unsupported by B::C during this stage." };
    require FileHandle;
}

use B::FAKEOP  ();
use B::STASHGV ();

use B::C::XS       ();
use B::C::OverLoad ();
use B::C::Save qw(savepv savestashpv);

# FIXME: this part can now be dynamic
# exclude all not B::C:: prefixed subs
# used in CV
our %all_bc_deps;

BEGIN {
    # track all internally used packages. all other may not be deleted automatically
    # - hidden methods
    # uses now @B::C::Flags::deps
    %all_bc_deps = map { $_ => 1 } @B::C::Flags::deps;
}

our ( $package_pv,     @package_pv );                 # global stash for methods since 5.13
our ( %xsub,           %init2_remap );
our ( %dumped_package, %skip_package, %isa_cache );

# fixme move to config
our ( $use_xsloader, $devel_peek_needed );

# options and optimizations shared with B::CC
our ($mainfile);

our @xpvav_sizes;
our $in_endav;
my %static_core_pkg;

sub start_heavy {
    my $settings = $B::C::settings;

    my $output_file = $settings->{'output_file'} or die("Please supply a -o option to B::C");
    B::C::File->new($output_file);    # Singleton.

    $settings->{'XS'} = B::C::XS->new(
        {
            'output_file'  => $output_file,
            'core_subs'    => $settings->{'CORE_subs'},
            'starting_INC' => $settings->{'starting_INC'},
            'dl_so_files'  => $settings->{'dl_so_files'},
            'dl_modules'   => $settings->{'dl_modules'},
        }
    );

    B::C::Debug::setup_debug( $settings->{'debug_options'}, $settings->{'enable_verbose'} );

    # Save some stuff we need to save early.
    save_pre_defstash();

    # save all our stashes at startup only
    save_defstash();

    # first iteration over the main tree
    save_optree();

    # fixups: wtf we could have miss during our initial walk...
    save_main_rest();

    return;
}

# used by B::OBJECT
sub add_to_isa_cache {
    my ( $k, $v ) = @_;
    die unless defined $k;

    $isa_cache{$k} = $v;
    return;
}

# This the Carp free workaround for DynaLoader::bootstrap
BEGIN {
    # Scoped no warnings without loading the module.
    local $^W;
    BEGIN { ${^WARNING_BITS} = 0; }
    *DynaLoader::croak = sub { die @_ }
}

sub walk_and_save_optree {
    my ( $name, $root, $start ) = @_;
    if ($root) {

        # B.xs: walkoptree does more, reifying refs. rebless or recreating it.
        verbose() ? walkoptree_slow( $root, "save" ) : walkoptree( $root, "save" );
    }
    return objsym($start);
}

my $saveoptree_callback;
BEGIN { $saveoptree_callback = \&walk_and_save_optree }
sub set_callback { $saveoptree_callback = shift }
sub saveoptree { &$saveoptree_callback(@_) }

# Look this up here so we can do just a number compare
# rather than looking up the name of every BASEOP in B::OP
# maybe use contant
our ( $OP_THREADSV, $OP_DBMOPEN, $OP_FORMLINE, $OP_UCFIRST );

BEGIN {
    $OP_THREADSV = opnumber('threadsv');
    $OP_DBMOPEN  = opnumber('dbmopen');
    $OP_FORMLINE = opnumber('formline');
    $OP_UCFIRST  = opnumber('ucfirst');
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

sub IsCOW {
    return ( ref $_[0] && $_[0]->can('FLAGS') && $_[0]->FLAGS & 0x10000000 );    # since 5.22
}

sub IsCOW_hek {
    return IsCOW( $_[0] ) && !$_[0]->LEN;
}

# fixme only use opsect common
my $opsect_common;

BEGIN {
    # should use a static variable
    # only for $] < 5.021002
    $opsect_common = "next, sibling, ppaddr, " . ( MAD() ? "madprop, " : "" ) . "targ, type, " . "opt, slabbed, savefree, static, folded, moresib, spare" . ", flags, private";
}

sub opsect_common { return $opsect_common }

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

# STATIC_HV: This function doesn't seem to be relevant in light of white listing.
sub method_named {
    my $name = shift;
    return unless $name;
    my $cop = shift;
    my $loc = $cop ? " at " . $cop->file . " line " . $cop->line : "";

    # Note: the pkg PV is unacessible(?) at PL_stack_base+TOPMARK+1.
    # But it is also at the const or padsv after the pushmark, before all args.
    # See L<perloptree/"Call a method">
    # We check it in op->_save_common
    if ( ref($name) eq 'B::CV' ) {
        WARN $name;
        return $name;
    }

    my $method;
    for ( $package_pv, @package_pv, 'main' ) {
        no strict 'refs';
        next unless defined $_;
        $method = $_ . '::' . $name;
        if ( defined(&$method) ) {
            last;
        }
        else {
            if ( my $parent = try_isa( $_, $name ) ) {
                $method = $parent . '::' . $name;
                last;
            }
            debug( cv => "no definition for method_name \"$method\"" );
        }
    }

    $method = $name unless $method;
    if ( exists &$method ) {    # Do not try to save non-existing methods
        debug( cv => "save method_name \"$method\"$loc" );
        return svref_2object( \&{$method} );
    }

    return 0;
}

# scalar: pv. list: (stash,pv,sv)
# pads are not named, but may be typed
sub padop_name {
    my $op = shift;
    my $cv = shift;
    if (
        $op->can('name')
        and (  $op->name eq 'padsv'
            or $op->name eq 'method_named'
            or ref($op) eq 'B::SVOP' )
      )    #threaded
    {
        return () if $cv and ref( $cv->PADLIST ) eq 'B::SPECIAL';
        my @c     = ( $cv and ref($cv) eq 'B::CV' and ref( $cv->PADLIST ) ne 'B::NULL' ) ? $cv->PADLIST->ARRAY : comppadlist->ARRAY;
        my @types = $c[0]->ARRAY;
        my @pad   = $c[1]->ARRAY;
        my $ix    = $op->can('padix') ? $op->padix : $op->targ;
        my $sv    = $pad[$ix];
        my $t     = $types[$ix];
        if ( defined($t) and ref($t) ne 'B::SPECIAL' ) {
            my $pv = $sv->can("PV") ? $sv->PV : ( $t->can('PVX') ? $t->PVX : '' );
            return $pv;
        }
        elsif ($sv) {
            my $pv = $sv->PV if $sv->can("PV");
            return $pv;
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

sub get_isa ($) {
    no strict 'refs';

    my $name = shift;
    return @{ B::C::get_linear_isa($name) };
}

# try_isa($pkg,$name) returns the found $pkg for the method $pkg::$name
# If a method can be called (via UNIVERSAL::can) search the ISA's. No AUTOLOAD needed.
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

sub load_utf8_heavy {
    require 'utf8_heavy.pl';
    svref_2object( \&{"utf8\::SWASHNEW"} )->save;

    return 1;
}

# If the sub or method is not found:
# 2. try UNIVERSAL::method
# 3. try compile-time expansion of AUTOLOAD to get the goto &sub addresses
sub try_autoload {
    my ( $cvstashname, $cvname ) = @_;
    no strict 'refs';
    return unless defined $cvstashname && defined $cvname;
    return 1 if try_isa( $cvstashname, $cvname );
    $cvname = '' unless defined $cvname;
    no strict 'refs';
    if ( defined( *{ 'UNIVERSAL::' . $cvname }{CODE} ) ) {
        debug( cv => "Found UNIVERSAL::$cvname" );
        return svref_2object( \&{ 'UNIVERSAL::' . $cvname } );
    }
    my $fullname = $cvstashname . '::' . $cvname;
    debug(
        cv => "No definition for sub %s. Try %s::AUTOLOAD",
        $fullname, $cvstashname
    );

    # First some exceptions, fooled by goto
    if ( $fullname eq 'utf8::SWASHNEW' ) {

        # utf8_heavy was loaded so far, so defer to a demand-loading stub
        # always require utf8_heavy, do not care if it s already in
        my $stub = sub { require 'utf8_heavy.pl'; goto &utf8::SWASHNEW };

        return svref_2object($stub);
    }

    # Handle AutoLoader classes. Any more general AUTOLOAD
    # use should be handled by the class itself.
    my @isa = get_isa($cvstashname);
    if ( $cvstashname =~ /^POSIX|Storable|DynaLoader|Net::SSLeay|Class::MethodMaker$/
        or ( exists ${ $cvstashname . '::' }{AUTOLOAD} and grep( $_ eq "AutoLoader", @isa ) ) ) {

        # Tweaked version of AutoLoader::AUTOLOAD
        my $dir = $cvstashname;
        $dir =~ s(::)(/)g;
        debug( cv => "require \"auto/$dir/$cvname.al\"" );
        eval { local $SIG{__DIE__}; require "auto/$dir/$cvname.al" unless $INC{"auto/$dir/$cvname.al"} };
        unless ($@) {
            verbose("Forced load of \"auto/$dir/$cvname.al\"");
            return svref_2object( \&$fullname )
              if defined &$fullname;
        }
    }

    # XXX TODO Check Selfloader (test 31?)
    svref_2object( \*{ $cvstashname . '::AUTOLOAD' } )->save
      if $cvstashname and exists ${ $cvstashname . '::' }{AUTOLOAD};
    svref_2object( \*{ $cvstashname . '::CLONE' } )->save
      if $cvstashname and exists ${ $cvstashname . '::' }{CLONE};
}

my @_v;

BEGIN {
    @_v = Internals::V();
}
sub __ANON__::_V { @_v }

sub save_object {
    foreach my $sv (@_) {
        svref_2object($sv)->save;
    }
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

sub walk_syms {
    my $package = shift;
    no strict 'refs';
    return if $dumped_package{$package};
    debug( pkg => "walk_syms $package" ) if verbose();
    $dumped_package{$package} = 1;
    walksymtable( \%{ $package . '::' }, "savecv", sub { 1 }, $package . '::' );
}

sub save_pre_defstash {

    # We need to save the INC GV before ANYTHING else is allowed to happen or we'll corrupt it.
    my %INC_BACKUP = %INC;
    %INC = %{ $settings->{'starting_INC'} };
    svref_2object( \%main::INC )->save("main::INC");
    %INC = %INC_BACKUP;

    # We need mro to save stashes but loading it alters the mro stash.
    if ( keys %{mro::} <= 10 ) {
        svref_2object( \%mro:: )->save("mro::");
        require 'mro.pm';
    }

    # do we have something else than PerlIO/scalar/scalar.so ?
    # there is something with PerlIO and PerlIO::scalar ( view in_static_core )
    if ( scalar @{ $settings->{'dl_modules'} } && scalar @{ $settings->{'dl_so_files'} } ) {    # Backup what we had in the DynaLoader arrays prior to C_Heavy
        my @modules = @DynaLoader::dl_modules;
        my @so      = @DynaLoader::dl_shared_objects;

        @DynaLoader::dl_modules        = @{ $settings->{'dl_modules'} };
        @DynaLoader::dl_shared_objects = @{ $settings->{'dl_so_files'} };

        svref_2object( \*DynaLoader::dl_modules )->save('@DynaLoader::dl_modules');
        svref_2object( \*DynaLoader::dl_shared_objects )->save('@DynaLoader::dl_shared_objects');

        @DynaLoader::dl_modules        = @modules;
        @DynaLoader::dl_shared_objects = @so;
    }

    # foreach my $stash ( qw{XSLoader DynaLoader} ) {
    #     no strict 'refs';
    #     #svref_2object( \%{ $stash . '::' } )->save( $stash .q{::} ) if B::HV::can_save_stash( $stash );
    # }
}

# Returns the symbol that will become &PL_defstash
sub save_defstash {

    my $PL_defstash = svref_2object( \%main:: )->save('main');

    $PL_defstash .= ' /* PL_defstash */';    # add a comment so we can easily detect it in our source code

    return $PL_defstash;
}

# simplified walk_syms
# needed to populate @B::C::Flags::deps from Makefile.PL from within this %INC context
sub walk_stashes {
    my ( $symref, $prefix, $dependencies ) = @_;
    no strict 'refs';
    $prefix = '' unless defined $prefix;
    foreach my $sym ( sort keys %$symref ) {
        if ( $sym =~ /::$/ ) {
            $sym = $prefix . $sym;
            $dependencies->{ substr( $sym, 0, -2 ) }++;
            if ( $sym ne "main::" && $sym ne "<none>::" ) {
                walk_stashes( \%$sym, $sym, $dependencies );
            }
        }
    }
}

# Used by Makefile.PL to autogenerate %INC deps.
# QUESTION: why Moose and IO::Socket::SSL listed here
# QUESTION: can we skip B::C::* here
sub collect_deps {
    my %deps;
    walk_stashes( \%main::, undef, \%deps );
    print join " ", ( sort keys %deps );
}

# XS in CORE which do not need to be bootstrapped extra.
# There are some specials like mro,re,UNIVERSAL.
sub in_static_core {
    my ( $stashname, $cvname ) = @_;
    if ( $stashname eq 'UNIVERSAL' ) {
        return $cvname =~ /^(isa|can|DOES|VERSION)$/;
    }
    %static_core_pkg = map { $_ => 1 } static_core_packages()
      unless %static_core_pkg;
    return 1 if $static_core_pkg{$stashname};
    if ( $stashname eq 'mro' ) {
        return $cvname eq 'method_changed_in';
    }
    if ( $stashname eq 're' ) {
        return $cvname =~ /^(is_regexp|regname|regnames|regnames_count|regexp_pattern)$/;
    }
    if ( $stashname eq 'PerlIO' ) {
        return $cvname eq 'get_layers';
    }
    if ( $stashname eq 'PerlIO::Layer' ) {
        return $cvname =~ /^(find|NoWarnings)$/;
    }
    return 0;
}

# XS modules in CORE. Reserved namespaces.
# Note: mro,re,UNIVERSAL have both, static core and dynamic/static XS
# version has an external ::vxs
sub static_core_packages {
    my @pkg = qw(Internals utf8 UNIVERSAL);

    push @pkg, 'version';

    #push @pkg, 'DynaLoader'	      if $Config{usedl};
    # Win32CORE only in official cygwin pkg. And it needs to be bootstrapped,
    # handled by static_ext.
    push @pkg, 'Cygwin'                     if $^O eq 'cygwin';
    push @pkg, 'NetWare'                    if $^O eq 'NetWare';
    push @pkg, 'OS2'                        if $^O eq 'os2';
    push @pkg, qw(VMS VMS::Filespec vmsish) if $^O eq 'VMS';

    push @pkg, split( / /, $Config{static_ext} );
    return @pkg;
}

sub skip_pkg {
    my $package = shift;
    if (
        $package =~ /^(main::)?(Internals|O)::/

        #or $package =~ /::::/ #  CORE/base/lex.t 54
        or $package =~ /^B::C::/
        or $package eq '__ANON__'
        or index( $package, " " ) != -1    # XXX skip invalid package names
        or index( $package, "(" ) != -1    # XXX this causes the compiler to abort
        or index( $package, ")" ) != -1    # XXX this causes the compiler to abort
        or exists $B::C::settings->{'skip_packages'}->{$package} or exists $skip_package{$package} or ( $DB::deep and $package =~ /^(DB|Term::ReadLine)/ )
      ) {
        return 1;
    }
    return 0;
}

# global state only, unneeded for modules
sub save_context {

    # forbid run-time extends of curpad syms, names and INC
    verbose("save context:");

    init()->add("/* honor -w */");
    init()->sadd( "PL_dowarn = ( %s ) ? G_WARN_ON : G_WARN_OFF;", $^W );
    if ( $^{TAINT} ) {
        init()->add(
            "/* honor -Tt */",
            "PL_tainting = TRUE;",

            # -T -1 false, -t 1 true
            "PL_taint_warn = " . ( $^{TAINT} < 0 ? "FALSE" : "TRUE" ) . ";"
        );
    }

    my ( $curpad_nam, $curpad_sym );
    {
        # Record comppad sv's names, may not be static
        local $B::C::const_strings = 0;
        init()->add("/* curpad names */");
        verbose("curpad names:");
        $curpad_nam = ( comppadlist->ARRAY )[0]->save('curpad_name');
        verbose("curpad syms:");
        init()->add("/* curpad syms */");
        $curpad_sym = ( comppadlist->ARRAY )[1]->save('curpad_syms');
    }

    init1()->add(
        "PL_curpad = AvARRAY($curpad_sym);",
        "PL_comppad = $curpad_sym;",      # fixed "panic: illegal pad"
        "PL_stack_sp = PL_stack_base;"    # reset stack (was 1++)
    );

    init1()->add(
        "PadlistNAMES(CvPADLIST(PL_main_cv)) = PL_comppad_name = $curpad_nam; /* namepad */",
        "PadlistARRAY(CvPADLIST(PL_main_cv))[1] = (PAD*)$curpad_sym; /* curpad */"
    );
}

sub save_optree {
    verbose("Starting compile");
    verbose("Walking optree");
    %Exporter::Cache = ();                # avoid B::C and B symbols being stored
    _delete_macros_vendor_undefined();

    if ( debug('walk') ) {
        verbose("Enabling B::debug / B::walkoptree_debug");
        B->debug(1);

        # this is enabling walkoptree_debug
        # which is useful when using walkoptree (not the slow version)
    }

    verbose()
      ? walkoptree_slow( main_root, "save" )
      : walkoptree( main_root, "save" );

    return;
}

sub _delete_macros_vendor_undefined {
    foreach my $class (qw(POSIX IO Fcntl Socket Exporter Errno)) {
        no strict 'refs';
        no strict 'subs';
        no warnings 'uninitialized';
        my $symtab = $class . '::';
        for my $symbol ( sort keys %$symtab ) {
            next if $symbol !~ m{^[0-9A-Z_]+$} || $symbol =~ m{(?:^ISA$|^EXPORT|^DESTROY|^TIE|^VERSION|^AUTOLOAD|^BEGIN|^INIT|^__|^DELETE|^CLEAR|^STORE|^NEXTKEY|^FIRSTKEY|^FETCH|^EXISTS)};
            next if ref $symtab->{$symbol};
            local $@;
            my $code = "$class\:\:$symbol();";
            eval $code;
            if ( $@ =~ m{vendor has not defined} ) {
                delete $symtab->{$symbol};
                next;
            }
        }
    }
    return 1;
}

sub force_saving_xsloader {
    init()->add("/* custom XSLoader::load_file */");

    # does this really save the whole packages?
    $dumped_package{DynaLoader} = 1;
    svref_2object( \&XSLoader::load_file )->save;
    svref_2object( \&DynaLoader::dl_load_flags )->save;    # not saved as XSUB constant?

    # add_hashINC("DynaLoader");
    $use_xsloader = 0;                                     # do not load again
}

sub save_main_rest {
    verbose("done main optree, walking symtable for extras");

    # startpoints: XXX TODO push BEGIN/END blocks to modules code.
    debug( av => "Writing init_av" );
    my $init_av = init_av->save('INIT');
    my $end_av;
    {
        # >=5.10 need to defer nullifying of all vars in END, not only new ones.
        local ($B::C::const_strings);
        $in_endav = 1;
        debug( 'av' => "Writing end_av" );
        init()->add("/* END block */");
        $end_av   = end_av->save('END');
        $in_endav = 0;
    }

    init()->add(
        "/* startpoints */",
        sprintf( "PL_main_root = s\\_%x;",  ${ main_root() } ),
        sprintf( "PL_main_start = s\\_%x;", ${ main_start() } ),
    );
    init()->add(
        index( $init_av, '(AV*)' ) >= 0
        ? "PL_initav = $init_av;"
        : "PL_initav = (AV*)$init_av;"
    );
    init()->add(
        index( $end_av, '(AV*)' ) >= 0
        ? "PL_endav = $end_av;"
        : "PL_endav = (AV*)$end_av;"
    );

    my %INC_BACKUP = %INC;
    save_context();

    # verbose("use_xsloader=$use_xsloader");
    # If XSLoader was forced later, e.g. in curpad, INIT or END block
    force_saving_xsloader() if $use_xsloader;

    return if $settings->{'check'};

    fixup_ppaddr();

    $settings->{'XS'}->write_lst();
    my $c_file_stash = build_template_stash();

    verbose("Writing output");
    %INC = %INC_BACKUP;    # Put back %INC now we've saved everything so Template can be loaded properly.
    B::C::File::write($c_file_stash);

    # Can use NyTProf with B::C
    if ( $INC{'Devel/NYTProf.pm'} ) {
        eval q/DB::finish_profile()/;
    }

    return;
}

### TODO:
##### remove stuff from boot  add use the template for EXTERN_C declaration
#####

sub build_template_stash {
    no strict 'refs';

    my $c_file_stash = {
        'verbose'            => verbose(),
        'debug'              => B::C::Debug::save(),
        'creator'            => "created at " . scalar localtime() . " with B::C $VERSION for $^X",
        'init_name'          => $settings->{'init_name'} || "perl_init",
        'gv_index'           => $gv_index,
        'init2_remap'        => \%init2_remap,
        'HAVE_DLFCN_DLOPEN'  => HAVE_DLFCN_DLOPEN(),
        'compile_stats'      => compile_stats(),
        'nullop_count'       => $nullop_count,
        'all_eval_pvs'       => \@B::C::InitSection::all_eval_pvs,
        'TAINT'              => ( ${^TAINT} ? 1 : 0 ),
        'devel_peek_needed'  => $devel_peek_needed,
        'MAX_PADNAME_LENGTH' => $B::PADNAME::MAX_PADNAME_LENGTH + 1,                                  # Null byte at the end?
        'PL'                 => {
            'defstash'    => save_defstash(),                                                                             # Re-uses the cache.
                                                                                                                          # we do not want the SVf_READONLY and SVf_PROTECT flags to be set to PL_curstname : newSVpvs_share("main")
            'curstname'   => svref_2object( \'main' )->save( undef, { update_flags => ~SVf_READONLY & ~SVf_PROTECT } ),
            'incgv'       => svref_2object( \*main::INC )->save("main::INC"),
            'hintgv'      => svref_2object( \*^H )->save("^H"),                                                           # This shouldn't even exist at run time!!!
            'defgv'       => svref_2object( \*_ )->save("_"),
            'errgv'       => svref_2object( \*@ )->save("@"),
            'replgv'      => svref_2object( \*^R )->save("^R"),
            'debstash'    => svref_2object( \%DB:: )->save("DB::"),
            'globalstash' => svref_2object( \%CORE::GLOBAL:: )->save("CORE::GLOBAL::"),
        },
        'XS' => $settings->{'XS'},
    };
    chomp $c_file_stash->{'compile_stats'};                                                                               # Injects a new line when you call compile_stats()

    # main() .c generation needs a buncha globals to be determined so the stash can access them.
    # Some of the vars are only put in the stash if they meet certain coditions.

    $c_file_stash->{'global_vars'} = {
        'dollar_caret_H'       => $^H,
        'dollar_caret_X'       => cstring($^X),
        'dollar_caret_UNICODE' => ${^UNICODE},
    };

    # PL_strtab's hash size
    $c_file_stash->{'PL_strtab_max'} = B::HV::get_max_hash_from_keys( sharedhe()->index() + 1, 511 ) + 1;

    return $c_file_stash;
}

sub found_xs_sub {
    my $sub = shift;

    $settings->{'XS'}->found_xs_sub($sub);

    return;
}

sub get_bootstrap_section {
    my $subname = shift;

    return init_COREbootstraplink() if $settings->{CORE_subs}->{$subname};

    # TODO
    return init_bootstraplink();
}

sub is_bootstrapped_cv {
    my $str = shift;

    return $1 if $str =~ m{BOOTSTRAP_XS_\Q[[\E(.+?)\Q]]\E_XS_BOOTSTRAP};
    return;
}

# init op addrs must be the last action, otherwise
# some ops might not be initialized
# but it needs to happen before CALLREGCOMP, as a /i calls a compiled utf8::SWASHNEW
sub fixup_ppaddr {
    foreach my $op_section_name ( B::C::File::op_sections() ) {
        my $section = B::C::File::get_sect($op_section_name);
        my $num     = $section->index;
        next unless $num >= 0;
        init_op_addr( $section->name, $num + 1 );
    }
}

# 5.15.3 workaround [perl #101336], without .bs support
# XSLoader::load_file($module, $modlibname, ...)
my $dlext;

BEGIN {
    $dlext = $Config{dlext};
    eval q|
sub XSLoader::load_file {
  #package DynaLoader;
  my $module = shift or die "missing module name";
  my $modlibname = shift or die "missing module filepath";
  print STDOUT "XSLoader::load_file(\"$module\", \"$modlibname\" @_)\n"
      if ${DynaLoader::dl_debug};

  push @_, $module;
  # works with static linking too
  my $boots = "$module\::bootstrap";
  goto &$boots if defined &$boots;

  my @modparts = split(/::/,$module); # crashes threaded, issue 100
  my $modfname = $modparts[-1];
  my $modpname = join('/',@modparts);
  my $c = @modparts;
  $modlibname =~ s,[\\/][^\\/]+$,, while $c--;    # Q&D basename
  die "missing module filepath" unless $modlibname;
  my $file = "$modlibname/auto/$modpname/$modfname."| . qq(."$dlext") . q|;

  # skip the .bs "bullshit" part, needed for some old solaris ages ago

  print STDOUT "goto DynaLoader::bootstrap_inherit\n"
      if ${DynaLoader::dl_debug} and not -f $file;
  goto \&DynaLoader::bootstrap_inherit if not -f $file;
  my $modxsname = $module;
  $modxsname =~ s/\W/_/g;
  my $bootname = "boot_".$modxsname;
  @DynaLoader::dl_require_symbols = ($bootname);

  my $boot_symbol_ref;
  if ($boot_symbol_ref = DynaLoader::dl_find_symbol(0, $bootname)) {
    print STDOUT "dl_find_symbol($bootname) ok => goto boot\n"
      if ${DynaLoader::dl_debug};
    goto boot; #extension library has already been loaded, e.g. darwin
  }
  # Many dynamic extension loading problems will appear to come from
  # this section of code: XYZ failed at line 123 of DynaLoader.pm.
  # Often these errors are actually occurring in the initialisation
  # C code of the extension XS file. Perl reports the error as being
  # in this perl code simply because this was the last perl code
  # it executed.

  my $libref = DynaLoader::dl_load_file($file, 0) or do {
    die("Can't load '$file' for module $module: " . DynaLoader::dl_error());
  };
  push(@DynaLoader::dl_librefs,$libref);  # record loaded object

  my @unresolved = DynaLoader::dl_undef_symbols();
  if (@unresolved) {
    die("Undefined symbols present after loading $file: @unresolved\n");
  }

  $boot_symbol_ref = DynaLoader::dl_find_symbol($libref, $bootname) or do {
    die("Can't find '$bootname' symbol in $file\n");
  };
  print STDOUT "dl_find_symbol($libref, $bootname) ok => goto boot\n"
    if ${DynaLoader::dl_debug};
  push(@DynaLoader::dl_modules, $module); # record loaded module

 boot:
  my $xs = DynaLoader::dl_install_xsub($boots, $boot_symbol_ref, $file);
  print STDOUT "dl_install_xsub($boots, $boot_symbol_ref, $file)\n"
    if ${DynaLoader::dl_debug};
  # See comment block above
  push(@DynaLoader::dl_shared_objects, $file); # record files loaded
  return &$xs(@_);
}
|;
}

sub init_op_addr {
    my ( $op_type, $num ) = @_;
    my $op_list = $op_type . "_list";

    init0()->add( split /\n/, <<_EOT3 );
{
    register int i;
    for( i = 0; i < ${num}; ++i ) {
        ${op_list}\[i].op_ppaddr = PL_ppaddr[PTR2IV(${op_list}\[i].op_ppaddr)];
    }
}
_EOT3

}

1;
