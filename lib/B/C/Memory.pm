package B::C::Memory;

use strict;

# number of structure malloced
my %MALLOC = ();

sub get_malloc_size {    # in char unit
    my $str_size = $MALLOC{'char'} // 0;

    foreach my $k ( sort keys %MALLOC ) {
        next if $k eq 'char';
        next unless $MALLOC{$k};
        if ( $k eq 'PERL_HV_ARRAY_ALLOC_BYTES' ) {    # function call
            $str_size .= sprintf( ' + %s(%d)', $k, $MALLOC{$k} );
        }
        else {                                        # math
            $str_size .= sprintf( ' + sizeof(%s) * %d', $k, $MALLOC{$k} );
        }
    }

    return $str_size;
}

### helpers ( maybe move them to a better place ? )

# this is a perl wrapper around the C call to HvSETUP
sub HvSETUP {

    # this is matching the C prototype for HvSETUP
    my ( $hv, $size, $has_ook, $backrefs_sym ) = @_;

    # increase a local counter to know how much memory we need to malloc
    $MALLOC{'PERL_HV_ARRAY_ALLOC_BYTES'} += $size;

    # PERL_HV_ARRAY_ALLOC_BYTES(size)
    ++$MALLOC{'struct xpvhv_aux'} if $has_ook;

    return sprintf( q{HvSETUP(%s, %d, %s, (SV*) %s);}, $hv, $size, $has_ook, $backrefs_sym );
}

# this is a perl wrapper around the C call to INITPADNAME
sub INITPADNAME {
    my ( $padname, $number_of_items ) = @_;

    $MALLOC{'PADNAME *'} += $number_of_items;

    return sprintf( q{INITPADNAME(%s, %d)}, $padname, $number_of_items );
}

# this is a perl wrapper around the C call to INITPADLIST
sub INITPADLIST {
    my ( $pad, $number_of_items ) = @_;

    $MALLOC{'PAD *'} += $number_of_items;
    return sprintf( q{INITPADLIST(%s, %d)}, $pad, $number_of_items );
}

1;
