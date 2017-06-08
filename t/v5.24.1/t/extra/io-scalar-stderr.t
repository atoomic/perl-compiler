#!perl

print "1..1\n";

my $out = '';
close STDERR;
{
    local *STDERR;
    open STDERR, ">", \$out;
    warn "ok\n";
}

chomp $out;
print "$out 1 - STDERR out:$out\n";
