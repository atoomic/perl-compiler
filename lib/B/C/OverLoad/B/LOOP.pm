package B::LOOP;

use strict;

use B::C::File qw/loopsect/;

sub do_save {
    my ($op) = @_;

    loopsect()->comment_for_op("first, last, redoop, nextop, lastop");
    my ( $ix, $sym ) = loopsect()->reserve( $op, "OP*" );
    loopsect()->debug( $op->name, $op );

    loopsect()->supdatel(
        $ix,
        '%s' => $op->save_baseop,
        '%s' => $op->first->save,
        '%s' => $op->last->save,
        '%s' => $op->redoop->save,
        '%s' => $op->nextop->save,
        '%s' => $op->lastop->save,
    );

    return $sym;
}

1;
