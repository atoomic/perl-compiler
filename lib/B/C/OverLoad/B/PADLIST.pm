package B::PADLIST;

use strict;
our @ISA = qw(B::AV);

use B::C::File qw/init_static_assignments padlistsect/;
use B::C::Helpers::Symtable qw/savesym/;

sub save_sv {    # id+outid as U32 (PL_padlist_generation++)
    my ($av) = @_;

    my $fill = $av->MAX;

    padlistsect()->comment("xpadl_max, xpadl_alloc, xpadl_id, xpadl_outid");
    my ( $id, $outid ) = ( $av->ID, $av->OUTID );
    my $padlist_index = padlistsect()->add("$fill, {NULL}, $id, $outid");

    return savesym( $av, "&padlist_list[$padlist_index]" );
}

sub add_to_init {
    my ( $av, $sym, $acc ) = @_;

    my $fill1 = $av->MAX + 1;

    init_static_assignments()->no_split;
    init_static_assignments()->add("{");
    init_static_assignments()->indent(+1);

    init_static_assignments()->sadd("register int gcount;") if $acc =~ m/\(gcount=/m;
    init_static_assignments()->sadd( "PAD **svp = INITPADLIST($sym, %d);", $fill1 );
    init_static_assignments()->sadd( substr( $acc, 0, -2 ) );

    init_static_assignments()->indent(-1);
    init_static_assignments()->add("}");
    init_static_assignments()->split;

    return;
}

sub cast_sv {
    return "(PAD*)";
}

sub fill { return shift->MAX }

1;
