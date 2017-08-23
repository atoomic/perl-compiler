#!/usr/local/cpanel/3rdparty/bin/perl

# > rm -f ./cpkeyclt; perlcc -UB::C cpkeyclt.pl; ./cpkeyclt

package MyPackage;

use strict;

sub hash {
    my $h = {};
    my $data = join "\n", 1 .. 120;    # 102 or larger ??

    foreach my $line ( split( /\n/, $data ) ) {
        $h->{0} = [ 1 .. 11 ];    # 8 or larger
        return;
    }
}

1;

package main;

MyPackage::hash();
print qq{1..1\nok 1\n};

__END__
1;
