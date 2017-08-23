my $q = qr[\p{IsWord}];
print qq[ok\n] if q[hello] =~ qr{$q};
