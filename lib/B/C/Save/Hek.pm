package B::C::Save::Hek;

use strict;

use B::C::Config;
use B::C::File qw(sharedhe sharedhestructs);
use B::C::Helpers qw/strlen_flags/;

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/save_shared_he/;

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

1;
