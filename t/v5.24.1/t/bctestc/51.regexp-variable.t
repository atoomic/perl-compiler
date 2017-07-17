
my $s = "toto";
my $k = qq[k\n];
$s =~ qr/to(?{ print "o$k";})/;
