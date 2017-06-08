package B::PADLIST;

use strict;
our @ISA = qw(B::AV);

use B::C::File qw/init padlistsect/;
use B::C::Helpers::Symtable qw/savesym/;

sub save_sv {    # id+outid as U32 (PL_padlist_generation++)
    my ( $av ) = @_;

    my $fill = $av->MAX;

    padlistsect()->comment("xpadl_max, xpadl_alloc, xpadl_id, xpadl_outid");
    my ( $id, $outid ) = ( $av->ID, $av->OUTID );
    my $padlist_index = padlistsect()->add("$fill, {NULL}, $id, $outid");

    return savesym( $av, "&padlist_list[$padlist_index]" );
}

sub add_to_init {
    my ( $av, $sym, $acc ) = @_;

    my $fill1 = $av->MAX + 1;

    init()->no_split;
    init()->add("{");
    init()->indent(+1);

    init()->sadd("register int gcount;") if $acc =~ qr{\bgcount\b};    # only if gcount is used
    init()->sadd( "PAD **svp = INITPADLIST($sym, %d);", $fill1 );
    init()->sadd( substr( $acc, 0, -2 ) );

    init()->indent(-1);
    init()->add("}");
    init()->split;

    return;
}

sub cast_sv {
    return "(PAD*)";
}

sub fill { return shift->MAX }

1;
