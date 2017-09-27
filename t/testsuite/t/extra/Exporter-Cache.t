#!perl

use Exporter;

print "1..1\n";

my $cached = join( ",", sort keys %Exporter::Cache );

# we clear the whole cache at compile time - maybe by mistake but not an issue so far
my $expect = is_compiled() ? '' : 'Exporter';

if ( $cached eq $expect ) {
    print qq[ok 1\n];
}
else {
    print "not ok 1 - $cached\n";
}

sub is_compiled {
    return $0 =~ qr{\.bin$} ? 1 : 0;
}
