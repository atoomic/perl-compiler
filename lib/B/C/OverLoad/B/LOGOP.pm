package B::LOGOP;

use strict;

use B::C::File qw/logopsect/;

sub do_save {
    my ($op) = @_;

    logopsect()->comment_common("first, other");
    my ( $ix, $sym ) = logopsect()->reserve( $op, "OP*" );
    logopsect()->debug( $op->name, $op );

    logopsect()->supdatel(
        $ix,
        '%s'       => $op->_save_common,
        '(OP*) %s' => $op->first->save,    # OP *    op_first;
        '(OP*) %s' => $op->other->save,    # OP *    op_other;
    );

    return $sym;
}

1;
