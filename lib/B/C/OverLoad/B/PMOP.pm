package B::PMOP;

use strict;

use B qw/cstring svref_2object RXf_EVAL_SEEN PMf_EVAL/;
use B::C::Config;
use B::C::File qw/pmopsect init init1 init2/;
use B::C::Helpers qw/read_utf8_string strlen_flags/;

# Global to this space?
my ($swash_init);

# FIXME really required ?
sub PMf_ONCE() { 0x10000 };    # PMf_ONCE also not exported

sub do_save {
    my ( $op, $level, $fullname ) = @_;
    my ( $replrootfield, $replstartfield, $gvsym ) = ( 'NULL', 'NULL' );

    $level    ||= 0;
    $fullname ||= '????';

    my $replroot  = $op->pmreplroot;
    my $replstart = $op->pmreplstart;
    my $ppaddr    = $op->ppaddr;

    # under ithreads, OP_PUSHRE.op_replroot is an integer. multi not.
    $replrootfield = sprintf( "s\\_%x", $$replroot ) if ref $replroot;
    if ($$replroot) {

        # OP_PUSHRE (a mutated version of OP_MATCH for the regexp
        # argument to a split) stores a GV in op_pmreplroot instead
        # of a substitution syntax tree. We don't want to walk that...
        if ( $op->name eq "pushre" ) {
            $gvsym          = $replroot->save;
            $replrootfield  = "NULL";
            $replstartfield = $replstart->save if $replstart;
            debug( gv => "PMOP::save saving a pp_pushre with GV $gvsym" );
        }
        else {
            $replstart->save if $replstart;
            $replstartfield = B::C::saveoptree( "*ignore*", $replroot, $replstart );
            $replstartfield =~ s/^hv/(OP*)hv/;
        }
    }

    # pmnext handling is broken in perl itself, we think. Bad op_pmnext
    # fields aren't noticed in perl's runtime (unless you try reset) but we
    # segfault when trying to dereference it to find op->op_pmnext->op_type

    pmopsect()->comment_common("first, last, pmoffset, pmflags, pmreplroot, pmreplstart");
    my $ix = pmopsect()->add(
        sprintf(
            "%s, s\\_%x, s\\_%x, %u, 0x%x, {%s}, {%s}",
            $op->_save_common, ${ $op->first },
            ${ $op->last },    0,
            $op->pmflags, $replrootfield, $replstartfield
        )
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

    pmopsect()->debug( $op->name, $op );
    my $pmsym = sprintf( "pmop_list[%d]", $ix );
    my $re = $op->precomp;

    if ( defined($re) ) {
        $B::C::Regexp{$$op} = $op;

        # TODO minor optim: fix savere( $re ) to avoid newSVpvn;
        my ( $qre, $relen, $utf8 ) = strlen_flags($re);

        my $pmflags = $op->pmflags;
        debug( gv => "pregcomp $pmsym $qre:$relen" . ( $utf8 ? " SVf_UTF8" : "" ) . sprintf( " 0x%x\n", $pmflags ) );

        # some pm need early init (242), SWASHNEW needs some late GVs (GH#273)
        # esp with 5.22 multideref init. i.e. all \p{} \N{}, \U, /i, ...
        # But XSLoader and utf8::SWASHNEW itself needs to be early.
        my $initpm = init1();

        if ( $qre =~ m/\\[pN]\{/ or $qre =~ m/\\U/ ) {
            $initpm = init2();
            print STDERR "XXXX $qre\n";
        }

        my $eval_seen = $op->reflags & RXf_EVAL_SEEN;
        $initpm->no_split();
        if ($eval_seen) {    # set HINT_RE_EVAL on
            $pmflags |= PMf_EVAL;
            $initpm->add('{');
            $initpm->indent(+1);
            $initpm->add('U32 hints_sav = PL_hints;');
            $initpm->add('PL_hints |= HINT_RE_EVAL;');
        }

        # XXX Modification of a read-only value attempted. use DateTime - threaded
        $initpm->sadd( "PM_SETRE(&%s, CALLREGCOMP(newSVpvn_flags(%s, %s, SVs_TEMP|%s), 0x%x));", $pmsym, $qre, $relen, $utf8 ? 'SVf_UTF8' : '0', $pmflags );
        $initpm->sadd( "RX_EXTFLAGS(PM_GETRE(&%s)) = 0x%x;", $pmsym, $op->reflags );

        if ($eval_seen) {    # set HINT_RE_EVAL off
            $initpm->add('PL_hints = hints_sav;');
            $initpm->indent(-1);
            $initpm->add('}');
        }
        $initpm->split();

        # See toke.c:8964
        # set in the stash the PERL_MAGIC_symtab PTR to the PMOP: ((PMOP**)mg->mg_ptr) [elements++] = pm;
        if ( $op->pmflags & PMf_ONCE() ) {
            my $stash = ref $op->pmstash eq 'B::HV' ? $op->pmstash->NAME : '__ANON__';
            $B::C::Regexp{$$op} = $op;    #188: restore PMf_ONCE, set PERL_MAGIC_symtab in $stash
        }
    }

    if ($gvsym) {

        # XXX need that for subst
        init()->sadd( "%s.op_pmreplrootu.op_pmreplroot = (OP*)%s;", $pmsym, $gvsym );
    }

    return "(OP*)&$pmsym";
}

1;
