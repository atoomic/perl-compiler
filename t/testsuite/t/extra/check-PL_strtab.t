package main;

print "1..2\n";

BEGIN {

    my $progname = $0;

    my $extra_cvs;
    if ( $0 =~ qr{-([0-9]+).t} ) {
        $extra_cvs = $1;
    }

    if ($extra_cvs) {
        print STDERR "# creating $extra_cvs EXTRA CVs\n";
        foreach my $i ( 1 .. $extra_cvs ) {
            my $sub = "_fake_sub_$i";
            no strict 'refs';
            *$sub = sub { };
        }
    }

    # we do not want to load these modules
    # we are using these names as we know
    #	this would result in using a different hash
    #	bucket than the one expected

    $INC{'Cpanel/Logger.pm'}            = '__FAKE__';
    $INC{'Cpanel/Logger/Persistent.pm'} = '__FAKE__';
}

package Cpanel::Logger;

sub new {
    my ($class) = @_;
    my $self = bless {}, $class;

    $self->{$class}              = 1;
    $self->{$class}              = "abcd";
    $self->{$class}->{something} = "something";
    $self->{$class}->{another}   = "another";

    return $self;
}

package Cpanel::Logger::Persistent;

use base 'Cpanel::Logger';

sub new {
    my ( $class, @args ) = @_;

    return $class->SUPER::new(@args);
}

package main;

# B::C is not going to be saved by B::C, let's hide it
eval q/BEGIN {
     # manually load B::C xs code
     require XSLoader;
     no warnings;
     XSLoader::load('B::C');

}/;

use B ();

check_strtab();

my $o = Cpanel::Logger->new();
print "# Cpanel::Logger => " . join( ", ", sort keys %$o ) . "\n";
print scalar( keys %$o ) == 1 ? "ok 1 - Cpanel::Logger\n" : "not ok 1 - Cpanel::Logger\n";

=pod

When initializing PL_strtab, if we are using an incorrect value for HvMAX
we will then fail to find on Shared_HEK... (store in an unexpected hash bucket)

This would result in creating a second HE, which would not use the same memory address...
whereas it would have every other value correct: key, hash...

hv_common will then not find the HE entry and create more than one HE for the same hash,
resulting in having a corrupted hash... (multiple keys in all point similar... just different HE !)

=cut

my $o = Cpanel::Logger::Persistent->new();
print "# Cpanel::Logger::Persistent => " . join( ", ", sort keys %$o ) . "\n";
print scalar( keys %$o ) == 1 ? "ok 2 - Cpanel::Logger::Persistent\n" : "not ok 2 - Cpanel::Logger::Persistent\n";

sub check_strtab {
    my $strtab;
    # hide B::C usage
    eval q/$strtab = B::C::strtab()/;

    my $obj  = B::svref_2object($strtab);
    my $keys = $obj->KEYS;
    my $max  = $obj->MAX;

    print "# strtab: KEYS:$keys - MAX:$max\n";

}
