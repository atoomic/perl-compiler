package B::SVOP;

use strict;

use B qw/SVf_ROK/;
use B::C::File qw/svopsect init/;
use B::C::Config;

sub do_save {
    my ($op) = @_;

    svopsect()->comment_common("sv");
    my ( $ix, $sym ) = svopsect()->reserve( $op, "OP*" );
    svopsect()->debug( $op->name, $op );

    my $svsym = 'Nullsv';

    # STATIC HV: This might be a bug now we have a static stash.
    # It might also be a XS op we need to be aware of and take special action beyond this.
    #
    # XXX moose1 crash with 5.8.5-nt, Cwd::_perl_abs_path also
    if ( $op->name eq 'aelemfast' and $op->flags & 128 ) {    #OPf_SPECIAL
        $svsym = '&PL_sv_undef';                              # pad does not need to be saved
        debug( sv => "SVOP->sv aelemfast pad %d\n", $op->flags );
    }
    elsif ( $op->name eq 'gv'
        and $op->next
        and $op->next->name eq 'rv2cv'
        and $op->next->next
        and $op->next->next->name eq 'defined' ) {

        # 96 do not save a gvsv->cv if just checked for defined'ness
        my $gv   = $op->sv;
        my $gvsv = svop_name($op);
        $svsym = '(SV*)' . $gv->save();
    }
    else {
        my $sv = $op->sv;
        $svsym = $sv->save( "svop " . $op->name );
        if ( $svsym =~ /^(gv_|PL_.*gv)/ ) {
            $svsym = '(SV*)' . $svsym;
        }
        elsif ( $svsym =~ /^\([SAHC]V\*\)\&sv_list/ ) {
            $svsym =~ s/^\([SAHC]V\*\)//;
        }
        else {
            $svsym =~ s/^\([GAPH]V\*\)/(SV*)/;
        }

        WARN( "Error: SVOP: " . $op->name . " $sv $svsym" ) if $svsym =~ /^\(SV\*\)lexwarn/;    #322
    }

    if ( $op->name eq 'method_named' ) {
        my $cv = method_named( svop_or_padop_pv($op), nextcop($op) );
        $cv->save if $cv;
    }
    my $is_const_addr = $svsym =~ m/Null|\&/;

    my $svop_sv = ( $is_const_addr ? $svsym : "Nullsv /* $svsym */" );
    svopsect()->supdate( $ix, "%s, (SV*) %s", $op->_save_common, $svop_sv );
    init()->add("svop_list[$ix].op_sv = (SV*) $svsym;") unless $is_const_addr;

    return $sym;
}

sub svimmortal {
    my $sym = shift;
    if ( $sym =~ /\(SV\*\)?\&PL_sv_(yes|no|undef|placeholder)/ ) {
        return 1;
    }
    return undef;
}

our ( $package_pv, @package_pv );    # global stash for methods since 5.13

# STATIC_HV: This function doesn't seem to be relevant in light of white listing.
sub method_named {
    my $name = shift;
    return unless $name;
    my $cop = shift;
    my $loc = $cop ? " at " . $cop->file . " line " . $cop->line : "";

    # Note: the pkg PV is unacessible(?) at PL_stack_base+TOPMARK+1.
    # But it is also at the const or padsv after the pushmark, before all args.
    # See L<perloptree/"Call a method">
    # We check it in op->_save_common
    if ( ref($name) eq 'B::CV' ) {
        WARN $name;
        return $name;
    }

    my $method;
    for ( $package_pv, @package_pv, 'main' ) {
        no strict 'refs';
        next unless defined $_;
        $method = $_ . '::' . $name;
        if ( defined(&$method) ) {
            last;
        }
        else {
            if ( my $parent = try_isa( $_, $name ) ) {
                $method = $parent . '::' . $name;
                last;
            }
            debug( cv => "no definition for method_name \"$method\"" );
        }
    }

    $method = $name unless $method;
    if ( exists &$method ) {    # Do not try to save non-existing methods
        debug( cv => "save method_name \"$method\"$loc" );
        return svref_2object( \&{$method} );
    }

    return 0;
}

# 1. called from method_named, so hashp should be defined
# 2. called from svop before method_named to cache the $package_pv
sub svop_or_padop_pv {
    my $op = shift;
    my $sv;
    if ( !$op->can("sv") ) {
        if ( $op->can('name') and $op->name eq 'padsv' ) {
            my @c   = comppadlist->ARRAY;
            my @pad = $c[1]->ARRAY;
            return $pad[ $op->targ ]->PV if $pad[ $op->targ ] and $pad[ $op->targ ]->can("PV");

            # This might fail with B::NULL (optimized ex-const pv) entries in the pad.
        }

        # $op->can('pmreplroot') fails for 5.14
        if ( ref($op) eq 'B::PMOP' and $op->pmreplroot->can("sv") ) {
            $sv = $op->pmreplroot->sv;
        }
        else {
            return $package_pv unless $op->flags & 4;

            # op->first is disallowed for !KIDS and OPpCONST_BARE
            return $package_pv if $op->name eq 'const' and $op->flags & 64;
            return $package_pv unless $op->first->can("sv");
            $sv = $op->first->sv;
        }
    }
    else {
        $sv = $op->sv;
    }

    # XXX see SvSHARED_HEK_FROM_PV for the stash in S_method_common pp_hot.c
    # In this hash the CV is stored directly
    if ( $sv and $$sv ) {

        return $sv->PV if $sv->can("PV");
        if ( ref($sv) eq "B::SPECIAL" ) {    # DateTime::TimeZone
                                             # XXX null -> method_named
            debug( gv => "NYI S_method_common op->sv==B::SPECIAL, keep $package_pv" );
            return $package_pv;
        }
        if ( $sv->FLAGS & SVf_ROK ) {
            goto missing if $sv->isa("B::NULL");
            my $rv = $sv->RV;
            if ( $rv->isa("B::PVGV") ) {
                my $o = $rv->IO;
                return $o->STASH->NAME if $$o;
            }
            goto missing if $rv->isa("B::PVMG");
            return $rv->STASH->NAME;
        }
        else {
          missing:
            if ( $op->name ne 'method_named' ) {

                # Called from first const/padsv before method_named. no magic pv string, so a method arg.
                # The first const pv as method_named arg is always the $package_pv.
                return $package_pv;
            }
            elsif ( $sv->isa("B::IV") ) {
                WARN(
                    sprintf(
                        "Experimentally try method_cv(sv=$sv,$package_pv) flags=0x%x",
                        $sv->FLAGS
                    )
                );

                # QUESTION: really, how can we test it ?
                # XXX untested!
                return svref_2object( method_cv( $$sv, $package_pv ) );
            }
        }
    }
    else {
        my @c   = comppadlist->ARRAY;
        my @pad = $c[1]->ARRAY;
        return $pad[ $op->targ ]->PV if $pad[ $op->targ ] and $pad[ $op->targ ]->can("PV");
    }
}


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

# scalar: pv. list: (stash,pv,sv)
# pads are not named, but may be typed
sub padop_name {
    my $op = shift;
    my $cv = shift;
    if (
        $op->can('name')
        and (  $op->name eq 'padsv'
            or $op->name eq 'method_named'
            or ref($op) eq 'B::SVOP' )
      )    #threaded
    {
        return () if $cv and ref( $cv->PADLIST ) eq 'B::SPECIAL';
        my @c     = ( $cv and ref($cv) eq 'B::CV' and ref( $cv->PADLIST ) ne 'B::NULL' ) ? $cv->PADLIST->ARRAY : comppadlist->ARRAY;
        my @types = $c[0]->ARRAY;
        my @pad   = $c[1]->ARRAY;
        my $ix    = $op->can('padix') ? $op->padix : $op->targ;
        my $sv    = $pad[$ix];
        my $t     = $types[$ix];
        if ( defined($t) and ref($t) ne 'B::SPECIAL' ) {
            my $pv = $sv->can("PV") ? $sv->PV : ( $t->can('PVX') ? $t->PVX : '' );
            return $pv;
        }
        elsif ($sv) {
            my $pv = $sv->PV if $sv->can("PV");
            return $pv;
        }
    }
}

# return the next COP for file and line info
sub nextcop {
    my $op = shift;
    while ( $op and ref($op) ne 'B::COP' and ref($op) ne 'B::NULL' ) { $op = $op->next; }
    return ( $op and ref($op) eq 'B::COP' ) ? $op : undef;
}

1;
