package Test::PL_strtab;

use B ();

BEGIN {
    # create some extra fake subs to create entries in PL_strtab and make it grows on demand

    if ( $ENV{FAKE_SUBS} ) {
        foreach my $i ( 1 .. $ENV{FAKE_SUBS} ) {
            my $sub = "_fake_sub_$i";
            no strict 'refs';
            *$sub = sub { };
        }
    }
}

BEGIN {
    # manually load B::C xs code
    require XSLoader;
    no warnings;
    XSLoader::load('B::C');
}

run(@ARGV) unless caller();

sub run {
    my $strtab = B::C::strtab();

    my $obj  = B::svref_2object($strtab);
    my $keys = $obj->KEYS;
    my $max  = $obj->MAX;

    print "KEYS:$keys\nMAX:$max\n";

}
