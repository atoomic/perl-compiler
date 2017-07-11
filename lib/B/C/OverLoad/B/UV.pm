package B::UV;

use strict;

use B::C::Flags ();

use B::C::File qw/svsect/;
use B::C::Decimal qw/u32fmt/;

sub do_save {
    my ( $sv, $fullname ) = @_;

    my ( $ix, $sym ) = svsect()->reserve($sv);
    svsect()->debug( $fullname, $sv );

    my $uvuformat = $B::C::Flags::Config{uvuformat};
    $uvuformat =~ s/"//g;    #" poor editor

    my $uvx = $sv->UVX;
    my $suff = $uvx > 2147483647 ? 'UL' : 'U';

    # Since 5.24 we can access the IV/NV/UV value from either the union from the main SV body
    # or also from the SvANY of it. View IV.pm for more information

    svsect()->supdatel(
        $ix,
        "BODYLESS_UV_PTR(%s)" => $sym,           # sv_any
        u32fmt()              => $sv->REFCNT,    # sv_refcnt
        '0x%x'                => $sv->FLAGS,     # sv_flags
        '{.svu_uv=%s}'        => "$uvx$suff",    # sv_u.svu_uv
    );

    return $sym;
}

1;
