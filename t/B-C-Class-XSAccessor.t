#!perl

# cpanel - t/B-C-Class-XSAccessor.t                 Copyright 2019 cPanel, L.L.C.
#                                                            All rights Reserved.
# copyright@cpanel.net                                          http://cpanel.net
# This code is subject to the cPanel license.  Unauthorized copying is prohibited

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Subtest;

use B qw/svref_2object/;

use B::C;

BEGIN {
    B::C::load_heavy;    # load XS
}

package Person;

# Options can be passed as a HASH reference, if preferred,
# which can also help Perl::Tidy to format the statement correctly.
use Class::XSAccessor {
    constructor => 'new',
    accessors   => [ 'name', 'email' ],
};

package main;

my ( $name, $email ) = ( q[Joe], q[joe@ely.cow] );

my $someone = Person->new( name => $name, email => $email );

isa_ok $someone, ['Person'], "create a Person";

note "without using accessors...";

my $cv = svref_2object( \&Person::name );
isa_ok $cv, 'B::CV';
is $cv->get_xs_accessor_key(), q[name], "get_xs_accessor_key for name";

note "now using accessors...";
is $someone->email, $email, "access to email";

$cv = svref_2object( \&Person::email );
isa_ok $cv, 'B::CV';
is $cv->get_xs_accessor_key(), q[email], "get_xs_accessor_key for email after access";

done_testing;
