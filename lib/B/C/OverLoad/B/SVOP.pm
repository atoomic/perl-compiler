package B::SVOP;

use strict;

use B qw/SVf_ROK/;
use B::C::File qw/svopsect init/;
use B::C::Debug qw/debug WARN/;

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
