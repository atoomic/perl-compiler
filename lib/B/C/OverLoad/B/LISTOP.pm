package B::LISTOP;

use strict;

use B::C::File qw/listopsect/;

sub do_save {
    my ($op) = @_;

    listopsect()->comment_for_op("first, last");
    my ( $ix, $sym ) = listopsect()->reserve( $op, "OP*" );
    listopsect()->debug( $op->name, $op );

    listopsect()->supdate( $ix, "%s, %s, %s", $op->save_baseop, $op->first->save, $op->last->save );

    return $sym;
}

1;
