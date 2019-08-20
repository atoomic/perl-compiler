#!perl

use Sub::Defer;

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
}

my $c = 0;

BEGIN {

    defer_sub 'main::something' => sub {
        eval q[
sub {
    # Acta deos numquam mortalia fallunt
    my $somevariable = ++$c % 5;
    return $somevariable; # another comment
}
];
    };

}

plan tests => 4;

is main::something(), 1, "main::something";
is main::something(), 2, "main::something";

my $token = q[NUM];
$token .= q[QUAM];
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

