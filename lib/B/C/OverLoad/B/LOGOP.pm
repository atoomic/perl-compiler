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
        '%s' => $op->_save_common,
        '%s' => $op->first->save,
        '%s' => $op->other->save
    );

    return $sym;
}

1;
