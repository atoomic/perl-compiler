package B::PADNAMELIST;

use strict;
our @ISA = qw(B::AV);

use B::C::File qw/init init_static_assignments padnamelistsect/;
use B::C::Helpers::Symtable qw/savesym/;

sub add_to_section {
    my ($av) = @_;

    padnamelistsect()->comment("xpadnl_fill, xpadnl_alloc, xpadnl_max, xpadnl_max_named, xpadnl_refcnt");

    # TODO: max_named walk all names and look for non-empty names
    my $refcnt   = $av->REFCNT + 1;    # XXX defer free to global destruction: 28
    my $fill     = $av->MAX;
    my $maxnamed = $av->MAXNAMED;

    my $ix = padnamelistsect->add("$fill, NULL, $fill, $maxnamed, $refcnt /* +1 */");

    my $sym = savesym( $av, "&padnamelist_list[$ix]" );

    return $sym;
}

sub add_to_init {
    my ( $av, $sym, $acc ) = @_;

    my $fill1 = $av->MAX + 1;

    init_static_assignments()->no_split;
    init_static_assignments()->add("{");
    init_static_assignments()->indent(+1);

    init_static_assignments()->sadd("register int gcount;") if $acc =~ qr{\bgcount\b};
    init_static_assignments()->sadd( "PADNAME **svp = INITPADNAME($sym, %d);", $fill1 );
    init_static_assignments()->sadd( substr( $acc, 0, -2 ) );

    init_static_assignments()->indent(-1);
    init_static_assignments()->add("}");
    init_static_assignments()->split;

    return;
}

sub cast_sv {
    return "(PADNAME*)";
}

sub fill { return shift->MAX }

1;
