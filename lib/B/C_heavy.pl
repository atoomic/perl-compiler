package B::C;
use strict;

BEGIN {
    require B::C::Flags;
    *Config = \%B::C::Flags::Config;
}

use B qw(minus_c sv_undef walkoptree walkoptree_slow main_root main_start peekop
  class cchar svref_2object compile_stats comppadlist hash
  init_av end_av opnumber cstring
  HEf_SVKEY SVf_POK SVf_ROK SVf_IOK SVf_NOK SVf_IVisUV SVf_READONLY);

use B::C::File qw( init2 init0 init decl free
  heksect binopsect condopsect copsect padopsect listopsect logopsect
  opsect pmopsect pvopsect svopsect unopsect svsect xpvsect xpvavsect xpvhvsect xpvcvsect xpvivsect xpvuvsect
  xpvnvsect xpvmgsect xpvlvsect xrvsect xpvbmsect xpviosect padlistsect loopsect sharedhe
);

use B::C::Packages qw/is_package_used mark_package_unused mark_package_used mark_package_removed get_all_packages_used/;

# Look this up here so we can do just a number compare
# rather than looking up the name of every BASEOP in B::OP
# maybe use contant
our $OP_THREADSV = opnumber('threadsv');
our $OP_DBMOPEN  = opnumber('dbmopen');
our $OP_FORMLINE = opnumber('formline');
our $OP_UCFIRST  = opnumber('ucfirst');

sub svop_name {
    my $op = shift;
    my $cv = shift;
    my $sv;
    if ( $op->can('name') and $op->name eq 'padsv' ) {
        return padop_name( $op, $cv );
    }
    else {
        if ( !$op->can("sv") ) {
            if ( ref($op) eq 'B::PMOP' and $op->pmreplroot->can("sv") ) {
                $sv = $op->pmreplroot->sv;
            }
            else {
                $sv = $op->first->sv
                  unless $op->flags & 4
                  or ( $op->name eq 'const' and $op->flags & 34 )
                  or $op->first->can("sv");
            }
        }
        else {
            $sv = $op->sv;
        }
        if ( $sv and $$sv ) {
            if ( $sv->FLAGS & SVf_ROK ) {
                return '' if $sv->isa("B::NULL");
                my $rv = $sv->RV;
                if ( $rv->isa("B::PVGV") ) {
                    my $o = $rv->IO;
                    return $o->STASH->NAME if $$o;
                }
                return '' if $rv->isa("B::PVMG");
                return $rv->STASH->NAME;
            }
            else {
                if ( $op->name eq 'gvsv' or $op->name eq 'gv' ) {
                    return $sv->STASH->NAME . '::' . $sv->NAME;
                }

                return
                    $sv->can('STASH') ? $sv->STASH->NAME
                  : $sv->can('NAME')  ? $sv->NAME
                  :                     $sv->PV;
            }
        }
    }
}

# return the next COP for file and line info
sub nextcop {
    my $op = shift;
    while ( $op and ref($op) ne 'B::COP' and ref($op) ne 'B::NULL' ) { $op = $op->next; }
    return ( $op and ref($op) eq 'B::COP' ) ? $op : undef;
}


sub IsCOW {
    return ( ref $_[0] && $_[0]->can('FLAGS') && $_[0]->FLAGS & 0x10000000 );    # since 5.22
}

sub IsCOW_hek {
    return IsCOW( $_[0] ) && !$_[0]->LEN;
}


# This pair is needed because B::FAKEOP::save doesn't scalar dereference
# $op->next and $op->sibling

# For 5.8:
# Current workaround/fix for op_free() trying to free statically
# defined OPs is to set op_seq = -1 and check for that in op_free().
# Instead of hardwiring -1 in place of $op->seq, we use $op_seq
# so that it can be changed back easily if necessary. In fact, to
# stop compilers from moaning about a U16 being initialised with an
# uncast -1 (the printf format is %d so we can't tweak it), we have
# to "know" that op_seq is a U16 and use 65535. Ugh.

# For 5.9 the hard coded text is the values for op_opt and op_static in each
# op.  The value of op_opt is irrelevant, and the value of op_static needs to
# be 1 to tell op_free that this is a statically defined op and that is
# shouldn't be freed.

# For 5.10 op_seq = -1 is gone, the temp. op_static also, but we
# have something better, we can set op_latefree to 1, which frees the children
# (e.g. savepvn), but not the static op.

# 5.8: U16 op_seq;
# 5.9.4: unsigned op_opt:1; unsigned op_static:1; unsigned op_spare:5;
# 5.10: unsigned op_opt:1; unsigned op_latefree:1; unsigned op_latefreed:1; unsigned op_attached:1; unsigned op_spare:3;
# 5.18: unsigned op_opt:1; unsigned op_slabbed:1; unsigned op_savefree:1; unsigned op_static:1; unsigned op_spare:3;
# 5.19: unsigned op_opt:1; unsigned op_slabbed:1; unsigned op_savefree:1; unsigned op_static:1; unsigned op_folded:1; unsigned op_spare:2;
# 5.21.2: unsigned op_opt:1; unsigned op_slabbed:1; unsigned op_savefree:1; unsigned op_static:1; unsigned op_folded:1; unsigned op_lastsib:1; unsigned op_spare:1;

# fixme only use opsect common
{
    # should use a static variable
    # only for $] < 5.021002
    my $opsect_common = "next, sibling, ppaddr, " . ( MAD() ? "madprop, " : "" ) . "targ, type, " . "opt, slabbed, savefree, static, folded, moresib, spare" . ", flags, private";

    sub opsect_common {
        return $opsect_common;
    }

}

# dummy for B::C, only needed for B::CC
sub label { }

# save alternate ops if defined, and also add labels (needed for B::CC)
sub do_labels ($$@) {
    my $op    = shift;
    my $level = shift;

    for my $m (@_) {
        no strict 'refs';
        my $mo = $op->$m if $m;
        if ( $mo and $$mo ) {
            label($mo);
            $mo->save($level)
              if $m ne 'first'
              or ( $op->flags & 4
                and !( $op->name eq 'const' and $op->flags & 64 ) );    #OPpCONST_BARE has no first
        }
    }
}

sub get_isa ($) {
    no strict 'refs';

    my $name = shift;
    if ( is_using_mro() ) {    # mro.xs loaded. c3 or dfs
        return @{ mro::get_linear_isa($name) };
    }

    # dfs only, without loading mro
    return @{ B::C::get_linear_isa($name) };
}

1;