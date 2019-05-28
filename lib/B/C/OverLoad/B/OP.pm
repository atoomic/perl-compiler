package B::OP;

use strict;

use B qw/opnumber/;

use B::C::Debug qw/debug verbose/;
use B::C::File qw/opsect init_xops/;
use B::C::Helpers::Symtable qw/objsym/;

my $OP_CUSTOM = opnumber('custom');

# special handling for nullified COP's.
my %OP_COP = ( opnumber('nextstate') => 1 );
debug( cops => %OP_COP );

our @DO_UPDATE_ARGS;    # avoid a local on @_ which bloat the binary

sub do_save {
    my ($op) = @_;

    my $type = $op->type;
    $B::C::nullop_count++ unless $type;

    opsect()->comment( basop_comment() );    # could also use comment_for_op
    my ( $ix, $sym ) = opsect()->reserve( $op, "OP*" );
    opsect()->debug( $op->name, $op );

    # view Sub::Call::Tail perldoc for more details ( could use it )
    @DO_UPDATE_ARGS = ( $ix, $sym, $op );
    goto &do_update;                         # avoid deep recursion calls by forcing a tail call with goto
}

sub do_update {
    my ( $ix, $sym, $op ) = @DO_UPDATE_ARGS;

    opsect()->update( $ix, $op->save_baseop );

    return $sym;
}

# See also init_op_ppaddr below; initializes the ppaddr to the
# OpTYPE; init_op_ppaddr iterates over the ops and sets
# op_ppaddr to PL_ppaddr[op_ppaddr]; this avoids an explicit assignment
# in perl_init ( ~10 bytes/op with GCC/i386 )
sub B::OP::fake_ppaddr {
    my $op = shift;
    return "NULL" unless $op->can('name');

    my $type = $op->type;
    my $name = $op->name;

    if ( $type == $OP_CUSTOM ) {

        # filled at run time with the correct addr from PL_custom_ops
        init_xops()->xop_used_by( $name, objsym($op) );
        return sprintf( "/* XOP %s */ NULL", $name );
    }

    # we are using this slot to store the OP TYPE
    #   which is going to be replaced at init time by init0
    #   maybe we could try a lazy init of the OP by using a fake OP

    # use a lazy OP to determine on demand the addr
    if ( 0 <= $type && $type < B::OP::max() ) {
        return '&Perl_pp_bc_goto_op';
    }

    # sanity check to see if this occurs
    #   we might want to return the Perl_pp_bc_goto_op also...
    die "Unknown OP type: $type / name: $name\n";

    return 'NULL';
}

sub basop_comment {
    return "next, sibparent, ppaddr, targ, type, opt, slabbed, savefree, static, folded, moresib, spare, flags, private";
}

sub save_baseop {
    my $op = shift;

    # view BASEOP in op.h
    # increase readability by using an array
    my @BASEOP = (
        '%s'   => $op->next->save,         # OP*     op_next;
                                           # this is using 'sibparent' method from our custom C.xs function - consider submit it upstream
        '%s'   => $op->sibparent->save,    # OP*     op_sibparent; # could be previously op_sibling
        '%s'   => $op->fake_ppaddr,        # OP*     (*op_ppaddr)(pTHX);
        '%u'   => $op->targ,               # PADOFFSET   op_targ;
        '%u'   => $op->type,               # PERL_BITFIELD16 op_type:9;
        '%u'   => $op->opt || 0,           # PERL_BITFIELD16 op_opt:1; -- was hardcoded to 0
        '%u'   => 0,                       # $op->slabbed || 0,            # PERL_BITFIELD16 op_slabbed:1; -- was hardcoded to 0
        '%u'   => $op->savefree || 0,      # PERL_BITFIELD16 op_savefree:1; -- was hardcoded to 0
        '%u'   => 1,                       # PERL_BITFIELD16 op_static:1; -- is hardcoded to 1
        '%u'   => $op->folded || 0,        # PERL_BITFIELD16 op_folded:1; -- was hardcoded to 0
        '%u'   => $op->moresib || 0,       # PERL_BITFIELD16 op_moresib:1; -- was hardcoded to 0
        '%u'   => $op->spare || 0,         # PERL_BITFIELD16 op_spare:1; -- was hardcoded to 0
        '0x%x' => $op->flags || 0,         # U8      op_flags;
        '0x%x' => $op->private || 0        # U8      op_private;
    );

    die qq[BASEOP definition need an even number of args] if scalar @BASEOP % 2;    # sanity check

    # some syntactic sugar
    my ( @keys, @values );

    while ( scalar @BASEOP ) {
        push @keys,   shift @BASEOP;                                                # key
        push @values, shift @BASEOP;                                                # value
    }

    my $template = join ', ', @keys;
    return sprintf( $template, @values );
}

# XXX HACK! duct-taping around compiler problems
sub isa { UNIVERSAL::isa(@_) }                                                      # walkoptree_slow misses that
sub can { UNIVERSAL::can(@_) }

1;
