package B::UV;

use strict;

use B::C::Flags ();

use B::C::Config;
use B::C::File qw/svsect init/;
use B::C::Decimal qw/u32fmt/;

sub do_save {
    my ( $sv, $fullname ) = @_;

    my $uvuformat = $B::C::Flags::Config{uvuformat};
    $uvuformat =~ s/"//g;    #" poor editor

    my $uvx = $sv->UVX;
    my $suff = $uvx > 2147483647 ? 'UL' : 'U';

    my $ix = svsect()->saddl(
        "%s"           => 'NULL',         # sv_any
        u32fmt()       => $sv->REFCNT,    # sv_refcnt
        '0x%x'         => $sv->FLAGS,     # sv_flags
        '{.svu_uv=%s}' => "$uvx$suff",    # sv_u.svu_uv
    );

    my $sym = sprintf( "&sv_list[%d]", $ix );

=pod
    Since 5.24 we can access the IV/NV/UV value from either the union from the main SV body
    or also from the SvANY of it...

    view IV.pm for more informations

=cut

    # the bc_SET_SVANY_FOR_BODYLESS_UV version just uses extra parens to be able to use a pointer [need to add patch to perl]
    init()->sadd( "bc_SET_SVANY_FOR_BODYLESS_UV(%s);", $sym );

    svsect()->debug( $fullname, $sv );

    return $sym;
}

1;
