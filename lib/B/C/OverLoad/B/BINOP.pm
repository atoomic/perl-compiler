package B::BINOP;

use strict;

use B qw/opnumber/;
use B::C::File qw/binopsect init/;

my $OP_CUSTOM;
BEGIN { $OP_CUSTOM = B::opnumber('custom') }

sub do_save {
    my ($op) = @_;

    binopsect->comment_common("first, last");
    my ( $ix, $sym ) = binopsect()->reserve( $op, "OP*" );
    binopsect->debug( $op->name, $op->flagspv );

    binopsect->supdate( $ix, "%s, %s, %s", $op->_save_common, $op->first->save, $op->last->save );

    my $ppaddr = $op->ppaddr;
    if ( $op->type == $OP_CUSTOM ) {
        my $ptr = $$op;
        if ( $op->name eq 'Devel_Peek_Dump' or $op->name eq 'Dump' ) {
            B::C::Debug::verbose('custom op Devel_Peek_Dump');
            $B::C::devel_peek_needed++;
            init()->sadd( "binop_list[%d].op_ppaddr = S_pp_dump;", $ix );
        }
        else {
            B::C::Debug::vebose( "Warning: Unknown custom op " . $op->name );
            init()->sadd( "binop_list[%d].op_ppaddr = Perl_custom_op_xop(aTHX_ INT2PTR(OP*, 0x%x));", $ix, $ppaddr, $$op );
        }
    }

    return $sym;
}

1;
