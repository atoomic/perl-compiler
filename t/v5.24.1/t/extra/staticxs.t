use Cwd ();
print qq{1..2\nok 1\n};

sub is_compiled {
    return $0 =~ qr{\.bin$} ? 1 : 0;
}
if ( is_compiled() ) {
    my $linked = qx{ldd $0};
    my $ok = $linked =~ qr{\QCwd/Cwd.so\E} ? 'ok': 'not ok';
    print "$ok - binary is linked with Cwd/Cwd.so\n";
} else {
    print "ok 2 - binary is not compiled\n";
}

