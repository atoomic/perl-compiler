package B::C::Save::Hek;

use strict;

use B::C::Config;
use B::C::File qw(meta_sharedhe);
use B::C::Helpers qw/strlen_flags/;

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/save_shared_he get_sHe_HEK/;

my %saved_shared_hash;

sub save_shared_he {
    my $key = shift;

    return 'NULL' unless defined $key;
    return $saved_shared_hash{$key} if $saved_shared_hash{$key};

    my ( $cstr, $len, $utf8 ) = strlen_flags($key);

    my $shared_he_sect = meta_sharedhe($len);

    my $ix = $shared_he_sect->saddl(
        '%s'                      => q{NULL},                  # HE *hent_next;  - set at init time
        '%s'                      => q{NULL},                  # HE *hent_hek; - set at init time
        '{ .hent_refcount = %s }' => q[IMMORTAL_PL_strtab],    # union { SV *hent_val;  Size_t hent_refcount; } he_valu; - immortal SHe
        '%d'                      => 0,                        # U32 hek_hash; - computed at startup/init
        '%d'                      => $len,                     # I32 hek_len;
        '%s'                      => $cstr,                    # char hek_key[ len + 1];
        '%s'                      => $utf8 ? 1 : 0,            #       char flags; --- FIXME - verify this
    );

    # cannot use sHe$ix directly as sharedhe_list is used in by init_pl_strtab and init_assign
    return $saved_shared_hash{$key} = $shared_he_sect->get_sym();
}

sub get_sHe_HEK {
    my ($shared_he) = @_;

    return q{NULL} if !defined $shared_he or $shared_he eq 'NULL';
    die qq{Cannot get she from '$shared_he'} unless $shared_he =~ qr{^meta_sharedhe};

    return sprintf( q{get_sHe_HEK(%s)}, $shared_he );
}

1;
