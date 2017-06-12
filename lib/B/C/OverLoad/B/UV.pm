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

    my $sv_ix = svsect()->index + 1;
    my $sym = sprintf( "&sv_list[%d]", $sv_ix );

    # Since 5.24 we can access the IV/NV/UV value from either the union from the main SV body
    # or also from the SvANY of it. View IV.pm for more information

    my $bodyless_pointer = sprintf( "((char*)%s)+STRUCT_OFFSET(struct STRUCT_SV, sv_u) - STRUCT_OFFSET(XPVUV, xuv_uv)", $sym );

    svsect()->saddl(
        "%s"           => $bodyless_pointer,    # sv_any
        u32fmt()       => $sv->REFCNT,          # sv_refcnt
        '0x%x'         => $sv->FLAGS,           # sv_flags
        '{.svu_uv=%s}' => "$uvx$suff",          # sv_u.svu_uv
    );

    svsect()->debug( $fullname, $sv );

    return $sym;
}

1;
