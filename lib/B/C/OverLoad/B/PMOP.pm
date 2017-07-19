package B::PMOP;

use strict;

use B qw/RXf_EVAL_SEEN PMf_EVAL SVf_UTF8/;
use B::C::Debug qw/debug/;
use B::C::File qw/pmopsect init init1 init2/;
use B::C::Helpers qw/strlen_flags/;

# Global to this space?
my ($swash_init);

# FIXME really required ?
sub PMf_ONCE() { 0x10000 };    # PMf_ONCE also not exported

sub do_save {
    my ($op) = @_;

    pmopsect()->comment_common("first, last, pmoffset, pmflags, pmreplroot, pmreplstart");
    my ( $ix, $sym ) = pmopsect()->reserve( $op, 'OP*' );
    $sym =~ s/^\(OP\*\)//;     # Strip off the typecasting for local use but other callers will get our casting.
    pmopsect()->debug( $op->name, $op );

    my $replroot  = $op->pmreplroot;
    my $replstart = $op->pmreplstart;
    my $ppaddr    = $op->ppaddr;

    my $replrootfield  = ( $replroot  && ref $replroot )  ? $replroot->save  || 'NULL' : 'NULL';
    my $replstartfield = ( $replstart && ref $replstart ) ? $replstart->save || 'NULL' : 'NULL';

    # pmnext handling is broken in perl itself, we think. Bad op_pmnext
    # fields aren't noticed in perl's runtime (unless you try reset) but we
    # segfault when trying to dereference it to find op->op_pmnext->op_type
    pmopsect()->supdate(
        $ix, "%s, %s, %s, %u, 0x%x, {%s}, {%s}",
        $op->_save_common, $op->first->save, $op->last->save, 0,
        $op->pmflags,      $replrootfield,   $replstartfield
    );

    my $code_list = $op->code_list;
    if ( $code_list and $$code_list ) {
        debug( gv => "saving pmop_list[%d] code_list $code_list (?{})", $ix );
        my $code_op = $code_list->save;
        if ($code_op) {

            # (?{}) code blocks
            init()->sadd( 'pmop_list[%d].op_code_list = %s;', $ix, $code_op );
        }
        debug( gv => "done saving pmop_list[%d] code_list $code_list (?{})", $ix );
    }

    my $re = $op->precomp;

    if ( defined($re) ) {
        $B::C::Regexp{$$op} = $op;

        # TODO minor optim: fix savere( $re ) to avoid newSVpvn;
        my ( $qre, $relen, $utf8 ) = strlen_flags($re);

        my $pmflags = $op->pmflags;
        debug( gv => "pregcomp $sym $qre:$relen" . ( $utf8 ? " SVf_UTF8" : "" ) . sprintf( " 0x%x\n", $pmflags ) );

        # some pm need early init (242), SWASHNEW needs some late GVs (GH#273)
        # esp with 5.22 multideref init. i.e. all \p{} \N{}, \U, /i, ...
        # But XSLoader and utf8::SWASHNEW itself needs to be early.
        my $initpm = init1();

        if (   $qre =~ m/\\[pNx]\{/
            || $qre =~ m/\\[Ut]/
            || ( $op->reflags & SVf_UTF8 || $utf8 ) ) {
            $initpm = init2();
        }

        my $eval_seen = $op->reflags & RXf_EVAL_SEEN;
        $initpm->open_block();
        if ($eval_seen) {    # set HINT_RE_EVAL on
            $pmflags |= PMf_EVAL;
            $initpm->add('U32 hints_sav = PL_hints;');
            $initpm->add('PL_hints |= HINT_RE_EVAL;');
        }

        # XXX Modification of a read-only value attempted. use DateTime - threaded
        $initpm->sadd( "PM_SETRE(%s, CALLREGCOMP(newSVpvn_flags(%s, %s, SVs_TEMP|%s), 0x%x));", $sym, $qre, $relen, $utf8 ? 'SVf_UTF8' : '0', $pmflags );
        $initpm->sadd( "RX_EXTFLAGS(PM_GETRE(%s)) = 0x%x;", $sym, $op->reflags );

        if ($eval_seen) {    # set HINT_RE_EVAL off
            $initpm->add('PL_hints = hints_sav;');
        }
        $initpm->close_block();

        # See toke.c:8964
        # set in the stash the PERL_MAGIC_symtab PTR to the PMOP: ((PMOP**)mg->mg_ptr) [elements++] = pm;
        if ( $op->pmflags & PMf_ONCE() ) {
            my $stash = ref $op->pmstash eq 'B::HV' ? $op->pmstash->NAME : '__ANON__';
            $B::C::Regexp{$$op} = $op;    #188: restore PMf_ONCE, set PERL_MAGIC_symtab in $stash
        }
    }

    if ( $replrootfield && $replrootfield ne 'NULL' ) {

        my $pmsym = $sym;
        $pmsym =~ s/^\&//;                # Strip '&' off the front.

        # XXX need that for subst
        init()->sadd( "%s.op_pmreplrootu.op_pmreplroot = (OP*)%s;", $pmsym, $replrootfield );
    }

    return "(OP*)" . $sym;
}

1;
