package main;

BEGIN {
    my $cwd = qx[pwd];
    chomp $cwd;
    unshift @INC, "$cwd/../t/bctestc";    # allow us to load the library
}
use myConstants;

sub ok {
    print qq[ok\n] if &myConstants::SOMETHING;
}

ok();

1;

