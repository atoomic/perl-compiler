package Cat::Food;

use Moo;

sub feed_lion {
    my $self = shift;
    my $amount = shift || 1;

    $self->pounds( $self->pounds - $amount );

    return 1;
}

has taste => (
    is => 'ro',
);

has brand => (
    is  => 'ro',
    isa => sub {
        die "Only SWEET-TREATZ supported!" unless $_[0] eq 'SWEET-TREATZ';
    },
);

has pounds => (
    is  => 'rw',
    isa => sub { die "$_[0] is too much cat food!" unless $_[0] < 15 },
);

1;

package main;

BEGIN {
    chdir 't' if -d 't';
    require './test.pl';
}

plan tests => 4;

my $full = Cat::Food->new(
    taste  => 'DELICIOUS.',
    brand  => 'SWEET-TREATZ',
    pounds => 10,
);

is ref $full, 'Cat::Food', "new Cat::Food";
is $full->pounds, 10, 'pounds == 10';

ok $full->feed_lion, 'feed_lion';
is $full->pounds, 9, 'pounds == 9';

