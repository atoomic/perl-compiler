package B::LISTOP;

use strict;

use B::C::File qw/listopsect/;

sub do_save {
    my ( $op ) = @_;

    listopsect()->comment_common("first, last");
    my ( $ix, $sym ) = listopsect()->reserve( $op, "OP*" );
    listopsect()->debug( $op->name, $op );

    listopsect()->supdate( $ix, "%s, %s, %s", $op->_save_common, $op->first->save, $op->last->save );

    return $sym;
}

1;
