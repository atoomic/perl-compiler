package B::UNOP;

use strict;

use B::C::File qw/unopsect/;

sub do_save {
    my ($op) = @_;

    unopsect()->comment_for_op("first");
    my ( $ix, $sym ) = unopsect()->reserve( $op, "OP*" );
    unopsect()->debug( $op->name, $op );

    # view Sub::Call::Tail perldoc for more details ( could use it )
    local @_ = ( $ix, $sym, $op );
    goto &do_update;    # avoid deep recursion calls by forcing a tail call with goto
}

sub do_update {
    my ( $ix, $sym, $op ) = @_;
    unopsect()->supdate( $ix, "%s, %s", $op->save_baseop, $op->first->save || 'NULL' );

    return $sym;
}

1;
