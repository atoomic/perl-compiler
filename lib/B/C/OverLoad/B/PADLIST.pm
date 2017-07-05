package B::PADLIST;

use strict;
our @ISA = qw(B::AV);

use B::C::File qw/padlistsect/;
use B::C::Helpers::Symtable qw/savesym/;

sub save_sv {    # id+outid as U32 (PL_padlist_generation++)
    my ($av) = @_;

    my $fill = $av->MAX;

    padlistsect()->comment("xpadl_max, xpadl_alloc xpadl_id, xpadl_outid");
    my ( $id, $outid ) = ( $av->ID, $av->OUTID );
    my $padlist_index = padlistsect()->add("$fill, {NULL}, $id, $outid");

    return savesym( $av, "&padlist_list[$padlist_index]" );
}

sub add_malloc_line_for_array_init {
    my ( $av, $deferred_init, $sym ) = @_;    # Ignores $fill passed in.

    my $fill = $av->MAX + 1;
    $deferred_init->sadd( "PAD **svp = %s;", B::C::Memory::INITPADLIST( $sym, $fill ) );
}

sub cast_sv {
    return "(PAD*)";
}

sub fill { return shift->MAX }

1;
