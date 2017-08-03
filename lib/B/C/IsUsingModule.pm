package B::C::IsUsingModule;

my $use_all_required_modules = 1;

sub import {
    my ( $package, @modules ) = @_;

    foreach my $m (@modules) {
        next unless defined $m;
        my $path = $m . '.pm';
        $path =~ s{::}{/}g;
        if ( exists $INC{$path} ) {
            print "Using: $m\n";
        }
        else {
            $use_all_required_modules = 0;
        }
    }

    return;
}

CHECK {    # weird but avoid parsing the command line output
    exit( $use_all_required_modules ? 0 : 1 );
}

1;
