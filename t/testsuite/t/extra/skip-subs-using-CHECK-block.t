#!./perl

package MyPackage;

sub mysub {
    return 42;
}

sub foo {
    return 'bar';
}

1;

package main;

print "1..2\n";

CHECK {
    # simple CHECK block to do not save subs
    #   CHECK blocks are not saved by B::C :-)

    my %rules = ( 'MyPackage' => [qw(mysub abcd xyz)] );
    foreach my $pkg ( sort keys %rules ) {

        foreach my $func ( @{ $rules{$pkg} } ) {
            no strict 'refs';
            undef *{"${pkg}::$func"};
            delete ${$pkg}{$func};
        }

    }
}

sub f {
    my $sub = 'MyPackage'->can('mysub');
    return $sub ? $sub->() : 0;
}

print "ok 1 - MyPackage::mysub is not compiled\n" if f() == 0;
print "ok 2 - foo() eq bar - uncompileed\n" if MyPackage::foo() eq 'bar';

1;
