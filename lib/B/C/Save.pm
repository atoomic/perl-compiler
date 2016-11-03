package B::C::Save;

use strict;

use B qw(cstring svref_2object);
use B::C::Config;
use B::C::File qw( xpvmgsect decl init const );
use B::C::Helpers qw/strlen_flags is_shared_hek cstring_cow cow_strlen_flags/;
use B::C::Save::Hek qw/save_shared_he/;

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/savepvn constpv savepv savecowpv inc_pv_index savestash_flags savestashpv/;

my %strtable;
my %cowtable;

# Two different families of save functions
#   save_* vs save*

my $pv_index = -1;

sub inc_pv_index {
    return ++$pv_index;
}

sub savecowpv {
    my $pv = shift;
    my ( $cstring, $cur, $len, $utf8 ) = cow_strlen_flags($pv);

    return @{ $cowtable{$cstring} } if defined $cowtable{$cstring};

    my $ix = const()->add('FAKE_CONST');
    my $pvsym = sprintf( "cowpv%d", $ix );

    const()->update( $ix, sprintf( "Static const char %s[] = %s;", $pvsym, $cstring ) );
    $cowtable{$cstring} = [ $pvsym, $cur, $len ];

    return ( $pvsym, $cur, $len );    # NOTE: $cur is total size of the perl string. len would be the length of the C string.
}

sub constpv {                         # could also safely use a cowpv
    return savepv( shift, 1 );
}

sub savepv {
    my $pv    = shift;
    my $const = shift;
    my ( $cstring, $len, $utf8 ) = strlen_flags($pv);

    return $strtable{$cstring} if defined $strtable{$cstring};
    my $pvsym = sprintf( "pv%d", inc_pv_index() );
    $const = $const ? " const" : "";
    if ( $cstring ne "0" ) {          # sic
        decl()->add( sprintf( "Static%s char %s[] = %s;", $const, $pvsym, $cstring ) );
        $strtable{$cstring} = $pvsym;
    }

    return $pvsym;
}

sub savepvn {
    my ( $dest, $pv, $sv, $cur ) = @_;
    my @init;

    $pv = pack "a*", $pv if defined $pv;

    # If READONLY and FAKE use newSVpvn_share instead. (test 75)
    if ( $sv and is_shared_hek($sv) ) {
        debug( sv => "Saving shared HEK %s to %s\n", cstring($pv), $dest );
        my $shared_he = save_shared_he($pv);
        push @init, sprintf( "%s = %s->shared_he_hek.hek_key;", $dest, $shared_he ) unless $shared_he eq 'NULL';
        if ( DEBUGGING() ) {    # we have to bypass a wrong HE->HEK assert in hv.c
            push @B::C::static_free, $dest;
        }
    }
    else {
        my $cstr = cstring($pv);
        my $cur ||= ( $sv and ref($sv) and $sv->can('CUR') and ref($sv) ne 'B::GV' ) ? $sv->CUR : length( pack "a*", $pv );
        if ( $sv and B::C::IsCOW($sv) ) {
            $cstr = cstring_cow( $pv, q{\000\001} );
            $cur += 2;
        }
        debug( sv => "Saving PV %s:%d to %s", $cstr, $cur, $dest );
        $cur = 0 if $cstr eq "" and $cur == 7;    # 317
        push @init, sprintf( "%s = savepvn(%s, %u); " . _caller_comment(), $dest, $cstr, $cur );
    }

    return @init;
}

sub _caller_comment {
    return '' unless debug('stack');

    my $s = '';
    foreach my $level ( 0 .. 20 ) {
        my @caller = grep { defined } caller($level);
        @caller = map { $_ =~ s{/usr/local/cpanel/3rdparty/perl/5[0-9]+/lib64/perl5/cpanel_lib/x86_64-linux-64int/}{lib/}; $_ } @caller;

        last if !scalar @caller or !defined $caller[0];
        $s .= join ' ', @caller;
        $s .= "\n";
    }

    return qq{/* $s */};
}

# performance optimization:
#    limit calls to gv_stashpvn when using CopSTASHPVN_set macro

# cache to only init it once
my %stashtable;

#my $hv_index = 0; # need to use it from HV
sub savestash_flags {
    my ( $name, $cstring, $len, $flags, $disable_gvadd ) = @_;
    return $stashtable{$name} if defined $stashtable{$name};
    my $hv_index = B::C::HV::get_index();
    $flags = $flags ? "$flags|GV_ADD" : "GV_ADD" if !$disable_gvadd;    # enabled by default
    my $sym = "hv$hv_index";
    decl()->add("Static HV *$sym;");
    B::C::HV::inc_index();
    if ($name) {                                                        # since 5.18 save @ISA before calling stashpv
        my @isa = B::C::get_isa($name);
        no strict 'refs';
        if ( @isa and exists ${ $name . '::' }{ISA} ) {
            svref_2object( \@{"$name\::ISA"} )->save("$name\::ISA");
        }
    }
    my $pvsym = $len ? constpv($name) : '""';
    $stashtable{$name} = $sym;
    init()->add(
        sprintf(
            "%s = gv_stashpvn(%s, %u, %s); /* $name */",
            $sym, $pvsym, $len, $flags
        )
    );

    return $sym;
}

sub savestashpv {
    my $name = shift;
    return savestash_flags( $name, strlen_flags($name), shift );
}

1;
