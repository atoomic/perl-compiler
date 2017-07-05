package B::PVOP;

use strict;

use B::C::File qw/pvopsect/;
use B::C::Save qw/savecowpv/;

sub do_save {
    my ($op) = @_;

    my ( $cow_sym, $cur, $len ) = savecowpv( $op->pv );

    pvopsect()->comment_common("pv");
    my ( $ix, $sym ) = pvopsect()->reserve( $op, "OP*" );
    pvopsect()->debug( $op->name, $op );

    pvopsect()->supdate( $ix, "%s, (char*)%s", $op->_save_common, $cow_sym );

    return $sym;
}

1;
