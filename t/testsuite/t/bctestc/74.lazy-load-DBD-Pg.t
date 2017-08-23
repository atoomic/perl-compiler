
use Exporter 5.57 'import';    # removing the Exporter version make it succeeds
use DBD::mysql ();             # require to make it fails

sub load {
    my $mod = shift;
    return ( eval "use $mod (); qq[ok\n]" or $@ );
}

print load('DBD::Pg');
