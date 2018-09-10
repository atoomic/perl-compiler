#!./perl

# simplified version of op/evalbytes.t
# 	which is a proof the B API for multiconcat need to return
#	both the plain & utf8 strings

print "1..1\n";

my $U_100 = "\304\200";
my $upcode = "XYZ:$U_100" . chr(256) . ":WINTER";

print qq[ok\n] if $upcode eq "XYZ:\x{c4}\x{80}\x{100}:WINTER";
