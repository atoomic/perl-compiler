package B::UNOP;

use strict;

use B::C::File qw/unopsect/;

sub do_save {
    my ($op) = @_;

    unopsect()->comment_common("first");
    my ( $ix, $sym ) = unopsect()->reserve( $op, "OP*" );
    unopsect()->debug( $op->name, $op );

    unopsect()->supdate( $ix, "%s, %s", $op->_save_common, $op->first->save || 'NULL' );

    return $sym;
}

1;
