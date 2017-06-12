package B::PVOP;

use strict;

use B::C::File qw/pvopsect/;
use B::C::Save qw/savecowpv/;

sub do_save {
    my ( $op, $level ) = @_;

    my ( $cow_sym, $cur, $len ) = savecowpv( $op->pv );

    pvopsect()->comment_common("pv");

    my $ix = pvopsect()->sadd( "%s, (char*)%s", $op->_save_common, $cow_sym );
    pvopsect()->debug( $op->name, $op );

    return "(OP*)&pvop_list[$ix]";
}

1;
