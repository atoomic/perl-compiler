package B::C::Save::Hek;

use strict;

use B::C::Config;
use B::C::File qw(sharedhe sharedhestructs);
use B::C::Helpers qw/strlen_flags/;

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/save_shared_he get_sHe_HEK/;

my %saved_shared_hash;

sub save_shared_he {
    my $key = shift;

    return 'NULL' unless defined $key;
    return $saved_shared_hash{$key} if $saved_shared_hash{$key};

    my ( $cstr, $cur, $utf8 ) = strlen_flags($key);

    sharedhestructs()->{_defined_once} //= {};
    if ( !sharedhestructs()->{_defined_once}->{$cur} ) {
        sharedhestructs->sadd( q{DEFINE_STATIC_SHARED_HE_STRUCT(%d);}, $cur );
        sharedhestructs()->{_defined_once}->{$cur} = 1;
    }

    #$cur *= -1 if $utf8;

    my $index = sharedhe()->index() + 1;
    sharedhe()->sadd( "ALLOC_sHe(%d, %d, %s, %d); /* sHe%d */", $index, $cur, $cstr, $utf8 ? 1 : 0, $index );

    # cannot use sHe$ix directly as sharedhe_list is used in by init_pl_strtab and init_assign
    return $saved_shared_hash{$key} = sprintf( q{sharedhe_list[%d]}, $index );
}

sub get_sHe_HEK {
    my ($shared_he) = @_;

    return q{NULL} if !defined $shared_he or $shared_he eq 'NULL';

    my $sharedhe_ix;
    if ( $shared_he =~ qr{^sharedhe_list\[([0-9]+)\]$} ) {
        $sharedhe_ix = $1;
    }

    die unless defined $sharedhe_ix;
    my $se = q{sHe} . $sharedhe_ix;

    return sprintf( q{get_sHe_HEK(%s)}, $se );
}

1;
