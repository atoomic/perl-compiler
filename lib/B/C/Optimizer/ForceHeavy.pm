package B::C::Optimizer::ForceHeavy;

use strict;
use B qw/svref_2object/;
use B::C::Config;

use Exporter ();
our @ISA = qw(Exporter);

our @EXPORT_OK = qw/force_heavy/;

my %cache;

my $RULE = q{(bytes|utf8)};

# for bytes and utf8 only
# TODO: Carp::Heavy, Exporter::Heavy
# special case: warnings::register via -fno-warnings
sub force_heavy {
    my ( $pkg, $fullname ) = @_;

    # only for bytes and utf8
    # QUESTION: what about Config_heavy.pl ?
    return unless $pkg && $pkg =~ m/^$RULE$/;

    # optional
    return if $fullname && $fullname !~ /^${RULE}::AUTOLOAD$/;

    no strict 'refs';

    return svref_2object( \*{ $pkg . "::AUTOLOAD" } );
}

1;
