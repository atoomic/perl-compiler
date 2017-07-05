package B::PADNAMELIST;

use strict;
our @ISA = qw(B::AV);

use B::C::File qw/padnamelistsect/;
use B::C::Helpers::Symtable qw/savesym/;

sub save_sv {
    my ($av) = @_;

    padnamelistsect()->comment("xpadnl_fill, xpadnl_alloc, xpadnl_max, xpadnl_max_named, xpadnl_refcnt");

    # TODO: max_named walk all names and look for non-empty names
    my $refcnt   = $av->REFCNT + 1;    # XXX defer free to global destruction: 28
    my $fill     = $av->MAX;
    my $maxnamed = $av->MAXNAMED;

    my $ix = padnamelistsect->add("$fill, NULL, $fill, $maxnamed, $refcnt");

    my $sym = savesym( $av, "&padnamelist_list[$ix]" );

    return $sym;
}

sub add_malloc_line_for_array_init {
    my ( $av, $deferred_init, $sym ) = @_;    # Ignores $fill passed in.

    my $fill = $av->MAX + 1;
    $deferred_init->sadd( "PADNAME **svp = %s;", B::C::Memory::INITPADNAME( $sym, $fill ) );
}

sub cast_sv {
    return "(PADNAME*)";
}

sub fill { return shift->MAX }

1;
