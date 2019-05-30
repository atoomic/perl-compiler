BEGIN {

    my $progname = $0;

    my $extra_cvs;
    if ( $0 =~ qr{-([0-9]+).t} ) {
        $extra_cvs = $1;
    }

    print STDERR "# begin block..\n";

    if ($extra_cvs) {
        print STDERR "# creating $extra_cvs EXTRA CVs\n";
        foreach my $i ( 1 .. $extra_cvs ) {
            my $sub = "_fake_sub_$i";
            no strict 'refs';
            *$sub = sub { };
        }
    }

    # we do not want to load these modules
    # we are using these names as we know
    #	this would result in using a different hash
    #	bucket than the one expected

    $INC{'Cpanel/Logger.pm'}            = '__FAKE__';
    $INC{'Cpanel/Logger/Persistent.pm'} = '__FAKE__';
}
