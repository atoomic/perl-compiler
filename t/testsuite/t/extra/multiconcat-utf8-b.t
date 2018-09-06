#!perl

=pod

This is a shorter version of xtestc/0166.t # ./t/testc.sh -X 16

=cut

use utf8;
binmode STDOUT, ":utf8";

print "1..1\n";

print "# start: \x{ABCD}\n";

my $x = q[japanese];
my $concat = "# XX=$x\x{ABCD}\n";
print $concat;
print qq[ok\n] if $concat eq qq[# XX=japaneseꯍ\n];