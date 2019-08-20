#!perl

package main;

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
}

my $x;

BEGIN {
    my $mortalusfallunt = 1 << 4;    # 16
    $mortalusfallunt += 1;
    $x = $mortalusfallunt;
}

plan tests => 3;

is $x, 17, "x set in BEGIN block using a tmp variable";

my $token = q[MORTALUS];
$token .= q[FALLUNT];
$token = lc $token;

if ( $0 =~ m{\.bin$} ) {
    my $cfile = $0;
    $cfile =~ s{bin$}{c};

    ok -e $cfile, "cfile exists $cfile";

    my $matches = int qx{grep -c $token $cfile};
    print "# '$token' matches $matches\n";
    is $matches, 0, "no '$token' found in the cfile";
}
else {
    ok( 1, "-- skipped not compiled" ) for 1 .. 2;
}

