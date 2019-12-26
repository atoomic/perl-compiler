#!perl

sub do_test {
  print "ok 1 - test at ".${^GLOBAL_PHASE}."\n";
}

sub AUTOLOAD {
    substr( $AUTOLOAD, 0, 1 + rindex( $AUTOLOAD, ':' ) ) = q<>;
    return do_test();
}

print "1..1\n";

# alter AUTOLOAD at compile time
BEGIN { test() }
# try to reuse it at run time
test();
