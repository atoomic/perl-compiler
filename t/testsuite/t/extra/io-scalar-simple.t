#!perl

print "1..1\n";

my $out = '';
open my $fh, '>', \$out;
print {$fh} "ok";

print "$out 1 - out:$out\n";

