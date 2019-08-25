#!perl

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
}


plan tests => 5;

my @patches = (
      q["cPanel - disable man installs"],
      q["cPanel - cPanel INC PATH"],
      q["cPanel - COW Static support"],
      q["cPanel - Disable xs handshake"],
);

if ( $0 =~ m{\.bin$} ) {
    my $cfile = $0;
    $cfile =~ s{bin$}{c};

    ok -e $cfile, "cfile exists $cfile";

    foreach my $patch ( @patches ) {
      my $matches = int qx{egrep -c '#define COWPV.*$patch' $cfile};

      print qq[# grep $patch matches $matches\n];
      is $matches, 0, "patches name is not leak in the cfile [COWPV]";
    }
}
else {
    my $tests = 1 + scalar @patches;
    ok( 1, "-- skipped not compiled" ) for 1 .. $tests;
}

