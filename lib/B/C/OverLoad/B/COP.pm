package B::COP;

use strict;

use B qw/cstring svref_2object/;
use B::C::Debug qw/debug/;
use B::C::File qw/init copsect decl/;
use B::C::Decimal qw/get_integer_value/;
use B::C::Helpers qw/strlen_flags/;

my %COPHHTABLE;
my %copgvtable;

sub do_save {
    my ($op) = @_;

    # TODO: if it is a nullified COP we must save it with all cop fields!
    debug( cops => "COP: line %d file %s\n", $op->line, $op->file );

    my ( $ix, $sym ) = copsect()->reserve( $op, "OP*" );
    copsect()->debug( $op->name, $op );

    # shameless cut'n'paste from B::Deparse
    my ( $warn_sv, $isint );
    my $warnings   = $op->warnings;
    my $is_special = ref($warnings) eq 'B::SPECIAL';
    my $warnsvcast = "(STRLEN*)";
    if ($is_special) {
        $warn_sv = 'pWARN_STD';
        $warn_sv = 'pWARN_ALL' if $$warnings == 4;     # use warnings 'all';
        $warn_sv = 'pWARN_NONE' if $$warnings == 5;    # use warnings 'all';
    }
    else {
        # LEXWARN_on: Original $warnings->save from 5.8.9 was wrong,
        # DUP_WARNINGS copied length PVX bytes.
        my $warn = bless $warnings, "B::LEXWARN";

        # TODO: isint here misses already seen lexwarn symbols
        ( $warn_sv, $isint ) = $warn->save;

        # XXX No idea how a &sv_list[] came up here, a re-used object. Anyway.
        $warn_sv = substr( $warn_sv, 1 ) if substr( $warn_sv, 0, 3 ) eq '&sv';
        $warn_sv = $warnsvcast . '&' . $warn_sv;
    }

    my $dynamic_copwarn = !$is_special ? 1 : 0;

    # Trim the .pl extension, to print the executable name only.
    my $file = $op->file;

    # cop_label now in hints_hash (Change #33656)
    my $add_label = $op->label ? 1 : 0;

    $op->save_hints($sym);

    if ($add_label) {

        # test 29 and 15,16,21. 44,45
        my $label = $op->label;
        my ( $cstring, $cur, $utf8 ) = strlen_flags($label);
        $utf8 = 'SVf_UTF8' if $cstring =~ qr{\\[0-9]};    # help a little utf8, maybe move it to strlen_flags
        init()->sadd(
            "Perl_cop_store_label(aTHX_ &cop_list[%d], %s, %u, %s);",
            $ix, $cstring, $cur, $utf8
        );
    }

    if ( !$is_special and !$isint ) {
        my $copw = $warn_sv;
        $copw =~ s/^\(STRLEN\*\)&//;

        # on cv_undef (scope exit, die, Attribute::Handlers, ...) CvROOT and all its kids are freed.
        # lexical cop_warnings need to be dynamic, but just the ptr to the static string.
        if ($copw) {
            my $dest = "cop_list[$ix].cop_warnings";

            # with DEBUGGING save_pvn returns ptr + PERL_MEMORY_DEBUG_HEADER_SIZE
            # which is not the address which will be freed in S_cop_free.
            # Need to use old-style PerlMemShared_, see S_cop_free in op.c (#362)
            # lexwarn<n> might be also be STRLEN* 0
            init()->sadd( "%s = (STRLEN*)savesharedpvn((const char*)%s, sizeof(%s));", $dest, $copw, $copw );
        }
    }

    # we should have already saved the GV for the file (exception for B and O)
    my $filegv = exists $main::{qq[_<$file]} ? svref_2object( \$main::{qq[_<$file]} )->save : 'Nullgv';
    $filegv = 'Nullgv' if $filegv eq 'NULL';

    # COP has a stash method
    my $stash = $op->stash ? $op->stash->save : q{Nullhv};

    # a COP needs to have a stash, fallback to PL_defstash when none found
    if ( !$stash or $stash eq 'NULL' or $stash eq 'Nullhv' ) {

        # view op/bless.t
        $stash = B::C::save_defstash();
    }

    # add the cop at the end
    copsect()->comment_common("BASEOP, line_t line, HV* stash, GV* filegv, U32 hints, U32 seq, STRLEN* warn_sv, COPHH* hints_hash");
    copsect()->supdatel(
        $ix,
        '%s'       => $op->_save_common,                        # BASEOP list
        '%u'       => $op->line,                                # /* line # of this command */
        '(HV*) %s' => $stash,                                   # HV *    cop_stash;  /* package line was compiled in */
        '(GV*) %s' => $filegv,                                  # GV *    cop_filegv; /* file the following line # is from */
        '%u'       => $op->hints,                               # U32     cop_hints;  /* hints bits from pragmata */
        '%s'       => get_integer_value( $op->cop_seq ),        # U32     cop_seq;    /* parse sequence number */
        '%s'       => !$dynamic_copwarn ? $warn_sv : 'NULL',    # STRLEN *    cop_warnings;   /* lexical warnings bitmask */
        '%s'       => q{NULL},                                  # COPHH * cop_hints_hash; /* compile time state of %^H. */
    );

    return $sym;
}

sub save_hints {
    my ( $op, $sym ) = @_;

    $sym =~ s/^\(OP\*\)//;

    my $hints = $op->hints_hash;
    return unless ref $hints;

    my $i = 0;
    if ( exists $COPHHTABLE{$$hints} ) {
        my $cophh = $COPHHTABLE{$$hints};
        return init()->sadd( "CopHINTHASH_set(%s, %s);", $sym, $cophh );
    }

    die unless ref $hints eq 'B::RHE';    # does it really happen ?

    my $hint_hv = $hints->HASH;
    my $cophh = sprintf( "cophh%d", scalar keys %COPHHTABLE );
    $COPHHTABLE{$$hints} = $cophh;
    decl()->sadd( "Static COPHH *%s;", $cophh );
    foreach my $k ( sort keys %$hint_hv ) {
        my ( $ck, $kl, $utf8 ) = strlen_flags($k);
        my $v = $hint_hv->{$k};
        next if $k eq ':';                # skip label, saved just after
        my $val = B::svref_2object( \$v )->save("\$^H{$k}");    ## .... problem ????
        if ($utf8) {
            init()->sadd(
                "%s = cophh_store_pvn(%s, %s, %d, 0, %s, COPHH_KEY_UTF8);",
                $cophh, $i ? $cophh : 'NULL', $ck, $kl, $val
            );
        }
        else {
            init()->sadd(
                "%s = cophh_store_pvs(%s, %s, %s, 0);",
                $cophh, $i ? $cophh : 'NULL', $ck, $val
            );
        }
        $i++;
    }

    return init()->sadd( "CopHINTHASH_set(%s, %s);", $sym, $cophh );
}

1;

__END__

#  define CopSTASH(c)       ((c)->cop_stash)
#  define CopFILE_set(c,pv)  CopFILEGV_set((c), gv_fetchfile(pv))

 #define BASEOP              \
     OP*     op_next;        \
     OP*     _OP_SIBPARENT_FIELDNAME;\
     OP*     (*op_ppaddr)(pTHX); \
     PADOFFSET   op_targ;        \
     PERL_BITFIELD16 op_type:9;      \
     PERL_BITFIELD16 op_opt:1;       \
     PERL_BITFIELD16 op_slabbed:1;   \
     PERL_BITFIELD16 op_savefree:1;  \
     PERL_BITFIELD16 op_static:1;    \
     PERL_BITFIELD16 op_folded:1;    \
     PERL_BITFIELD16 op_moresib:1;       \
     PERL_BITFIELD16 op_spare:1;     \
     U8      op_flags;       \
     U8      op_private;
 #endif

 struct cop {
     BASEOP
     /* On LP64 putting this here takes advantage of the fact that BASEOP isn't
        an exact multiple of 8 bytes to save structure padding.  */
     line_t      cop_line;       /* line # of this command */
     /* label for this construct is now stored in cop_hints_hash */
     HV *    cop_stash;  /* package line was compiled in */
     GV *    cop_filegv; /* file the following line # is from */

     U32     cop_hints;  /* hints bits from pragmata */
     U32     cop_seq;    /* parse sequence number */
     /* Beware. mg.c and warnings.pl assume the type of this is STRLEN *:  */
     STRLEN *    cop_warnings;   /* lexical warnings bitmask */
     /* compile time state of %^H.  See the comment in op.c for how this is
        used to recreate a hash to return from caller.  */
     COPHH * cop_hints_hash;
 };
