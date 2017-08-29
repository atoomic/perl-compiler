package B::UNOP;

use strict;

use B::C::File qw/unopsect/;

sub do_save {
    my ($op) = @_;

    unopsect()->comment_for_op("first");
    my ( $ix, $sym ) = unopsect()->reserve( $op, "OP*" );
    unopsect()->debug( $op->name, $op );

    unopsect()->supdate( $ix, "%s, %s", $op->save_baseop, $op->first->save || 'NULL' );

    return $sym;
}

1;
