package B::PADNAMELIST;

use strict;
our @ISA = qw(B::AV);

use B::C::File qw/padnamelistsect/;

sub section_sv {
    return padnamelistsect();
}

sub update_sv {
    my ( $av, $ix, $fullname ) = @_;

    my $section = $av->section_sv();
    $section->comment("xpadnl_fill, xpadnl_alloc, xpadnl_max, xpadnl_max_named, xpadnl_refcnt");

    # TODO: max_named walk all names and look for non-empty names
    my $refcnt   = $av->REFCNT;
    my $fill     = $av->MAX;
    my $maxnamed = $av->MAXNAMED;

    $section->update( $ix, "$fill, NULL, $fill, $maxnamed, $refcnt" );

    return;
}

sub add_malloc_line_for_array_init {
    my ( $av, $deferred_init, $sym ) = @_;    # Ignores $fill passed in.

    my $fill = $av->MAX + 1;
    $deferred_init->sadd( "PADNAME **svp = %s;", B::C::Memory::INITPADNAME( $sym, $fill ) );
}

sub cast_sv {
    return "(PADNAME*)";
}

sub cast_section {                            ### Stupid move it to section !!! a section know its type
    return "PADNAMELIST*";
}

sub fill { return shift->MAX }

1;
