package B::UNOP;

use strict;

use B::C::File qw/unopsect/;

my @save_later;
my $deferred_saving = 0;

sub do_save {
    my ($op) = @_;

    unopsect()->comment_common("first");
    my ( $ix, $sym ) = unopsect()->reserve( $op, "OP*" );
    unopsect()->debug( $op->name, $op );

    # We prevent deep recursion here and in B::OP by not recursing until we've saved everything at our depth first.
    if ( !$deferred_saving ) {
        $deferred_saving = 1;
        unopsect()->supdate( $ix, "%s, %s", $op->_save_common, $op->first->save || 'NULL' );
        $deferred_saving = 0;
    }
    else {
        push @save_later, [ $ix, $op ];
    }

    while ( !$deferred_saving && @save_later ) {
        my $to_save = pop @save_later;
        unopsect()->supdate( $to_save->[0], "%s, %s", $to_save->[1]->_save_common, $to_save->[1]->first->save || 'NULL' );
    }

    return $sym;
}

1;
