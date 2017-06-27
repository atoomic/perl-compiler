package MyErrno;
require Exporter;
use strict;

our $VERSION = "1.25";
$VERSION = eval $VERSION;
our @ISA = 'Exporter';

our %err;

BEGIN {
    %err = (
        TEST => 42,
    );

    foreach my $name ( keys %err ) {

        # if ($MyErrno::{$name}) {
        #     # We expect this to be reached fairly rarely, so take an approach
        #     # which uses the least compile time effort in the common case:
        #     eval "sub $name() { $err{$name} }; 1" or die $@;
        # } else {
        $MyErrno::{$name} = \$err{$name};

        #}
    }
}

our @EXPORT_OK = keys %err;

our %EXPORT_TAGS = (
    POSIX => [
        qw(
          TEST
          )
    ],
);

package main;

print qq{ok\n} if &MyErrno::TEST;


