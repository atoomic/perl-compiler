#!perl

# this is an alternate version to what was known as xtestc/0237.t
print "1..2\n";

my $out = '';
{
    open OUT, ">", \$out;
    print OUT "\000\000\000\000_";
}

print "ok 1 - len [$out]\n"   if length($out) == 5;
print "ok 2 - match\n" if $out eq "\000\000\000\000_";
