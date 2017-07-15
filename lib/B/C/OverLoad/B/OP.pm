package B::OP;

use strict;

use B qw/opnumber/;

use B::C::Debug qw/debug verbose/;
use B::C::File qw/init copsect opsect/;

my $OP_CUSTOM = opnumber('custom');

# special handling for nullified COP's.
my %OP_COP = ( opnumber('nextstate') => 1 );
debug( cops => %OP_COP );

my @save_later;
my $deferred_saving = 0;

sub do_save {
    my ($op) = @_;

    my $type = $op->type;
    $B::C::nullop_count++ unless $type;

    opsect()->comment( B::C::opsect_common() );
    my ( $ix, $sym ) = opsect()->reserve( $op, "OP*" );
    opsect()->debug( $op->name, $op );

    # We prevent deep recursion here and in B::UNOP by not recursing until we've saved everything at our depth first.
    if ( !$deferred_saving ) {
        $deferred_saving = 1;
        opsect()->update( $ix, $op->_save_common );
        $deferred_saving = 0;
    }
    else {
        push @save_later, [ $ix, $op ];
    }

    while ( !$deferred_saving && @save_later ) {
        my $to_save = pop @save_later;
        opsect()->update( $to_save->[0], $to_save->[1]->_save_common );
    }

    return $sym;
}

# See also init_op_ppaddr below; initializes the ppaddr to the
# OpTYPE; init_op_ppaddr iterates over the ops and sets
# op_ppaddr to PL_ppaddr[op_ppaddr]; this avoids an explicit assignment
# in perl_init ( ~10 bytes/op with GCC/i386 )
sub B::OP::fake_ppaddr {
    my $op = shift;
    return "NULL" unless $op->can('name');
    if ( $op->type == $OP_CUSTOM ) {
        return ( verbose() ? sprintf( "/*XOP %s*/NULL", $op->name ) : "NULL" );
    }
    return sprintf( "INT2PTR(void*,OP_%s)", uc( $op->name ) );
}

sub _save_common {
    my $op = shift;

    return sprintf(
        "%s, %s, %s, %u, %u, 0, 0, 0, 1, 0, 0, 0, 0x%x, 0x%x",
        $op->next->save    || 'NULL',
        $op->sibling->save || 'NULL',
        $op->fake_ppaddr, $op->targ, $op->type, $op->flags || 0, $op->private || 0
    );
}

# XXX HACK! duct-taping around compiler problems
sub isa { UNIVERSAL::isa(@_) }    # walkoptree_slow misses that
sub can { UNIVERSAL::can(@_) }

1;
