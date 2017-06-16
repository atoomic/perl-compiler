package B::C::Section::Meta;

use strict;
use warnings;

use B::C::Section ();

sub new {
    my ( $class, $name, $sym_table_ref ) = @_;

    my $self = {
        name          => $name,
        sym_table_ref => $sym_table_ref,
        sections      => {},
    };
    bless $self, $class;

    return $self;
}

# create the section if missing/unknpwm
sub get_section {
    my ( $self, $section_name ) = @_;

    return $self unless defined $section_name;

    if ( !exists $self->{sections}->{$section_name} ) {
        ### probably need to do more: like adding the declaration for the first time

        my $name = $self->{name} . $section_name;

        # use one helper ???
        #B::C::File::presections()->add( sprintf( q{DEFINE_META_%s(%s)}, uc( $self->{name} ), $section_name ) );
        add_typedef_for( $self->{name}, $section_name );

        $self->{sections}->{$section_name} = B::C::Section->new( $name, $self->{sym_table_ref}, 0 );
    }

    return $self->{sections}->{$section_name};
}

sub get_all_sections {
    my $self = shift;

    my @list;
    foreach my $k ( sort keys %{ $self->{sections} } ) {
        my $section = $self->{sections}->{$k};
        next unless $section->index >= 0;
        push @list, $section;
    }

    return @list;
}

sub total_entries {
    my $self = shift;

    my @sections = get_all_sections();

    my $count = 0;
    foreach my $section (@sections) {
        next if my $ix = $section->index < 0;
        $count += $ix + 1;
    }

    return $count;
}

### TODO: better moving all meta to their own class just there as a proof of concept for now
sub add_typedef_for {
    my ( $structname, $custom ) = @_;

    $structname = uc($structname);
    $custom     = uc($custom);

    my $fullname = $structname . $custom;

    my $typedef;

    if ( $structname eq 'META_UNOPAUX_ITEM' ) {
        my $list = q{};
        my $id   = q{aaaa};
        for ( 1 .. int($custom) ) {
            $list .= qq[UNOP_AUX_item $id; ];
            ++$id;    # increase our fake id
        }

        $typedef = qq[typedef struct { $list } $fullname;];
    }
    elsif ( $structname eq 'META_SHAREDHE' ) {
        my $len = int($custom);
        $typedef = qq[struct _sHeS_$len { HE *hent_next; HEK *hent_hek; union { SV *hent_val;  Size_t hent_refcount; } he_valu;  U32 hek_hash;  I32 hek_len;  char hek_key[ $len + 1]; char flags; };];
    }
    else {
        die "unknown structname $structname";
    }

    B::C::File::typedef()->add($typedef);

}

1;
