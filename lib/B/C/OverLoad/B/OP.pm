package B::OP;

use strict;

use B qw/peekop cstring threadsv_names opnumber/;

use B::C::Config;
use B::C::File qw/init copsect opsect/;

my $OP_CUSTOM = opnumber('custom');

my @threadsv_names;

BEGIN {
    @threadsv_names = threadsv_names();
}

# special handling for nullified COP's.
my %OP_COP = ( opnumber('nextstate') => 1 );
debug( cops => %OP_COP );

sub do_save {
    my ($op) = @_;

    my $type = $op->type;
    $B::C::nullop_count++ unless $type;

    if ( ref($op) eq 'B::OP' ) {    # check wrong BASEOPs
                                    # [perl #80622] Introducing the entrytry hack, needed since 5.12, fixed with 5.13.8 a425677
                                    #   ck_eval upgrades the UNOP entertry to a LOGOP, but B gets us just a B::OP (BASEOP).
                                    #   op->other points to the leavetry op, which is needed for the eval scope.
        if ( $op->name eq 'entertry' ) {
            verbose("[perl #80622] Upgrading entertry from BASEOP to LOGOP...");
            bless $op, 'B::LOGOP';
            return $op->save;
        }
    }

    # HV_STATIC: Why are we saving a null row?
    # since 5.10 nullified cops free their additional fields
    if ( !$type and $OP_COP{ $op->targ } ) {
        debug( cops => "Null COP: %d\n", $op->targ );

        copsect()->comment_common("line, stash, file, hints, seq, warnings, hints_hash");
        my $ix = copsect()->sadd(
            "%s, 0, %s, NULL, 0, 0, NULL, NULL",
            $op->_save_common, "Nullhv"
        );

        return "(OP*)&cop_list[$ix]";
    }
    else {
        opsect()->comment( B::C::opsect_common() );
        my $ix = opsect()->add( $op->_save_common );
        opsect()->debug( $op->name, $op );

        debug(
            op => "  OP=%s targ=%d flags=0x%x private=0x%x\n",
            peekop($op), $op->targ, $op->flags, $op->private
        );
        return "(OP*) &op_list[$ix]";
    }
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
        $op->next->save,
        $op->sibling->save,
        $op->fake_ppaddr, $op->targ, $op->type, $op->flags, $op->private
    );
}

# XXX HACK! duct-taping around compiler problems
sub isa { UNIVERSAL::isa(@_) }    # walkoptree_slow misses that
sub can { UNIVERSAL::can(@_) }

1;
