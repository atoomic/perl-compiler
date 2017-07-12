package B::PADLIST;

use strict;
our @ISA = qw(B::AV);

use B::C::File qw/padlistsect/;
use B::C::Helpers::Symtable qw/savesym/;

sub section_sv {
    return padlistsect();
}

sub update_sv {    # id+outid as U32 (PL_padlist_generation++)
    my ( $av, $ix, $fullname ) = @_;

    my $section = $av->section_sv();
    $section->comment("xpadl_max, xpadl_alloc, xpadl_id, xpadl_outid");
    $section->supdatel(
        $ix,
        '%s' => $av->MAX,     # xpadl_max
        '%s' => '{NULL}',     # xpadl_alloc
        '%s' => $av->ID,      # xpadl_id
        '%s' => $av->OUTID    # xpadl_outid
    );

    return;
}

sub add_malloc_line_for_array_init {
    my ( $av, $deferred_init, $sym ) = @_;    # Ignores $fill passed in.

    my $fill = $av->MAX + 1;
    $deferred_init->sadd( "PAD **svp = INITPADLIST(%s, %d);", $sym, $fill );
}

sub cast_sv {
    return "(PAD*)";
}

sub cast_section {                            ### Stupid move it to section !!! a section know its type
    return "PADLIST*";
}

sub fill { return shift->MAX }

1;
