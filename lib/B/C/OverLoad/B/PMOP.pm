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

my %saved_re;

sub do_save {
    my ($op) = @_;

    pmopsect()->comment_common("first, last, pmoffset, pmflags, pmreplroot, pmreplstart");
    my ( $ix, $sym ) = pmopsect()->reserve( $op, 'OP*' );
    $sym =~ s/^\(OP\*\)//;     # Strip off the typecasting for local use but other callers will get our casting.
    pmopsect()->debug( $op->name, $op );

    my $replroot  = $op->pmreplroot;
    my $replstart = $op->pmreplstart;
    my $ppaddr    = $op->ppaddr;

    my $replrootfield;
    my $replrootfield_cast = '';
    if ( $op->name eq 'split' ) {    # maybe apply to all OPs
        $replrootfield = 'NULL';
        if ( defined $replroot ) {
            if ( ref $replroot ) {
                $replrootfield = $replroot->save;
            }
            elsif ( $replroot =~ qr{^[0-9]+$} ) {
                $replrootfield_cast = '.op_pmtargetoff=';
                $replrootfield      = $replroot;
            }
        }
    }
    else {
        $replrootfield = ( defined $replroot && ref $replroot ) ? $replroot->save || 'NULL' : 'NULL';
    }

    # FIXME - to check can probably be replaced by
    #my $replrootfield  = ( defined $replroot  && ref $replroot )  ? $replroot->save  || 'NULL' : $replroot;

    my $replstartfield = ( defined $replstart && ref $replstart ) ? $replstart->save || 'NULL' : 'NULL';

    # pmnext handling is broken in perl itself, we think. Bad op_pmnext
    # fields aren't noticed in perl's runtime (unless you try reset) but we
    # segfault when trying to dereference it to find op->op_pmnext->op_type
    pmopsect()->supdatel(
        $ix,
        '%s'   => $op->_save_common,                       # BASEOP
        '%s'   => $op->first->save,                        # OP *    op_first
        '%s'   => $op->last->save,                         # OP *    op_last
        '%u'   => 0,                                       # REGEXP *    op_pmregexp
        '0x%x' => $op->pmflags,                            #  U32         op_pmflags
        '{%s}' => $replrootfield_cast . $replrootfield,    # union op_pmreplrootu
                                                           # union {
                                                           # OP *    op_pmreplroot;      /* For OP_SUBST */
                                                           # PADOFFSET op_pmtargetoff;   /* For OP_SPLIT lex ary or thr GV */
                                                           # GV *    op_pmtargetgv;          /* For OP_SPLIT non-threaded GV */
                                                           # }   op_pmreplrootu;
        '{%s}' => $replstartfield,                         # union op_pmstashstartu
                                                           # union {
                                                           # OP *    op_pmreplstart; /* Only used in OP_SUBST */
                                                           # HV *    op_pmstash;
                                                           # }       op_pmstashstartu;
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

        # TODO minor optim: fix savere( $re ) to avoid newSVpvn;
        my ( $qre, $relen, $utf8 ) = strlen_flags($re);

        my $pmflags = $op->pmflags;
        debug( gv => "pregcomp $sym $qre:$relen" . ( $utf8 ? " SVf_UTF8" : "" ) . sprintf( " 0x%x\n", $pmflags ) );

        # some pm need early init (242), SWASHNEW needs some late GVs (GH#273)
        # esp with 5.22 multideref init. i.e. all \p{} \N{}, \U, /i, ...
        # But XSLoader and utf8::SWASHNEW itself needs to be early.
        my $initpm = init1();

        if (   $qre =~ m/\\[pNx]\{/
            || $qre =~ m/\\U/
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

        my $key = sprintf( "((%s, %s, SVs_TEMP|%s), 0x%x, 0x%x)", $qre, $relen, $utf8 ? 'SVf_UTF8' : '0', $pmflags, $op->reflags );
        my $pre_saved_sym = $saved_re{$key};

        # XXX Modification of a read-only value attempted. use DateTime - threaded
        if (
            $pre_saved_sym &&    # If we have already seen this regex
            !$eval_seen    &&    # and it does not have an eval
            $qre !~ tr{()}{}     # and it does not have a capture
          ) {                    # we can just use the reference.

            my $comment = $qre;
            $comment =~ s{\Q/*\E}{??}g;
            $comment =~ s{\Q*/\E}{??}g;

            $initpm->sadd( "PM_SETRE(%s, ReREFCNT_inc(PM_GETRE(%s))); /* %s */", $sym, $pre_saved_sym, $comment );
        }
        else {
            $initpm->sadd( "PM_SETRE(%s, CALLREGCOMP(newSVpvn_flags(%s, %s, SVs_TEMP|%s), 0x%x));", $sym, $qre, $relen, $utf8 ? 'SVf_UTF8' : '0', $pmflags );
            $initpm->sadd( "RX_EXTFLAGS(PM_GETRE(%s)) = 0x%x;", $sym, $op->reflags );
            $saved_re{$key} = $sym;
        }

        if ($eval_seen) {    # set HINT_RE_EVAL off
            $initpm->add('PL_hints = hints_sav;');
        }
        $initpm->close_block();
    }

    if ( $replrootfield && $replrootfield ne 'NULL' ) {

        my $pmsym = $sym;
        $pmsym =~ s/^\&//;    # Strip '&' off the front.

        # XXX need that for subst
        init()->sadd( "%s.op_pmreplrootu.op_pmreplroot = (OP*)%s;", $pmsym, $replrootfield );
    }

    return "(OP*)" . $sym;
}

1;
