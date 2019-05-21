package B::C::InitSection;
use strict;
use warnings;

# avoid use vars
our @ISA = qw/B::C::Section/;

use B::C::Debug qw(debug);
use B qw(cstring);
use B::C::Helpers qw/gv_fetchpv_to_fetchpvn_flags/;

# All objects inject into this shared variable.
our @all_eval_pvs;

sub new {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    $self->{'initav'}       = [];
    $self->{'chunks'}       = [];
    $self->{'nosplit'}      = 0;
    $self->{'current'}      = [];
    $self->{'count'}        = 0;
    $self->{'indent_level'} = 0;
    $self->{'max_lines'}    = 10000;
    $self->{'last_caller'}  = '';

    $self->benchmark_time( 'START', 'START init' );

    return $self;
}

sub has_values {
    my ( $self ) = @_;

    # we cannot use the 'count' value has it's reset when adding chunks..

    # either we already have a chunk
    return 1 if scalar @{ $self->{'chunks'} };
    # or we have some values in current
    return 1 if scalar @{ $self->{'current'} };

    return;
}

{
    my $status;
    my %blacklist;    # disable benchmark inside some specific sections
    my $init_benchmark;

    sub benchmark_enabled {
        my $self = shift;

        unless ($init_benchmark) {
            my $assign_sections = B::C::File->can('assign_sections') or die;
            $blacklist{$_} = 1 for $assign_sections->();
            $init_benchmark = 1;
        }

        return 0 if $blacklist{ $self->{name} };
        $status = debug('benchmark') || 0 unless defined $status;
        return $status;
    }
}

sub benchmark_time {
    my ( $self, $label ) = @_;

    return unless $self->benchmark_enabled();
    push @{ $self->{'current'} }, sprintf( qq{\nbenchmark_time("%s");\n}, $label );
    return;
}

sub indent {
    my ( $self, $inc ) = @_;
    return $self->{indent_level} unless defined $inc;
    $self->{indent_level} += $inc;
    $self->{indent_level} = 0 if $self->{indent_level} < 0;
    return $self->{indent_level};
}

sub split {
    my $self = shift;
    $self->{'nosplit'}--
      if $self->{'nosplit'} > 0;
    return $self->{'nosplit'};
}

sub no_split {
    return shift->{'nosplit'}++;
}

sub open_block {
    my ( $self, $comment ) = shift;

    # make it a C comment style
    $comment = sprintf( q{/* %s */}, $comment ) if $comment;

    $self->no_split;
    $self->sadd( "{ %s", $comment // '' );
    $self->indent(+1);

    return;
}

sub close_block {
    my $self = shift;

    $self->indent(-1);
    $self->add('}');
    $self->split;

    return;
}

sub inc_count {
    my $self = shift;

    $self->{'count'} += $_[0];

    # this is cheating
    return $self->add();
}

sub add {
    my ( $self, @lines ) = @_;

    my $current = $self->{'current'};
    my $nosplit = $self->{'nosplit'};

    if ( grep { $_ =~ m/\S/ } @_ ) {

        my $caller = "@{[(caller(1))[3]]}";
        if ( $caller =~ m/Section/ ) {    # Special handler for sadd calls.
            $caller = "@{[(caller(2))[3]]}";
        }

        $caller =~ s/::[^:]+?$//;
        $caller =~ s/^B:://;

        if ( $self->{'last_caller'} ne $caller ) {
            if ( $self->{'last_caller'} ) {
                $self->benchmark_time( $self->{'last_caller'} );

                # add a comment for comming code
                push @$current, sprintf( qq{\n/*%s %s %s*/\n}, '*' x 15, $caller, '*' x 15 );
            }

            $self->{'last_caller'} = $caller;
        }
    }

    my $indent = $self->indent();
    my $spaces = $indent ? "\t" x $indent : '';
    push @$current, map { "$spaces$_" } @lines;
    $self->{'count'} += scalar(@lines);

    if ( debug('stack') ) {
        my $add_stack = 'B::C::Save'->can('_caller_comment');
        my $stack     = $add_stack->();
        push @$current, $stack if length $stack;
    }

    if ( !$nosplit && $self->{'count'} >= $self->{'max_lines'} ) {
        push @{ $self->{'chunks'} }, $current;
        $self->{'current'} = [];
        $self->{'count'}   = 0;
    }
}

sub add_eval {
    my $self    = shift;
    my @strings = @_;

    foreach my $i (@strings) {
        $i =~ s/\"/\\\"/g;

        # We need to output evals after dl_init.
        push @all_eval_pvs, qq{eval_pv("$i",1);};    # The whole string.
    }
}

sub pre_destruct {
    my $self = shift;

    return $self->{'pre_destruct'} if ( !@_ );       # Return the array to the template if nothing is passed in.

    push @{ $self->{'pre_destruct'} }, @_;
}

sub add_initav {
    my $self = shift;
    push @{ $self->{'initav'} }, @_;
}

sub fixup_assignments {
    my $self = shift;

}

sub output {
    my ( $self, $format, $init_name ) = @_;
    my $sym = $self->symtable || {};
    my $default = $self->default;

    push @{ $self->{'chunks'} }, $self->{'current'};

    my $output = '';

    my $comment = $self->comment;
    $output .= q{/* } . $comment . qq{*/\n\n} if defined $comment;

    my $name = "aaaa";
    foreach my $i ( @{ $self->{'chunks'} } ) {

        # dTARG and dSP unused -nt
        $output .= "static void ${init_name}_${name}(pTHX)\n{\n";

        foreach my $i ( @{ $self->{'initav'} } ) {
            $output .= "    $i\n";
        }
        foreach my $j (@$i) {
            $j =~ s{(s\\_[0-9a-f]+)}
                   { exists($sym->{$1}) ? $sym->{$1} : $default; }ge;

            while ( $j =~ m{BOOTSTRAP_XS_\Q[[\E(.+?)\Q]]\E_XS_BOOTSTRAP} ) {
                my $sub   = $1;
                my $getcv = sprintf(
                    q{GvCV( %s )},
                    gv_fetchpv_to_fetchpvn_flags( $sub, 0, 'SVt_PVCV' )
                );
                $j =~ s{BOOTSTRAP_XS_\Q[[\E(.+?)\Q]]\E_XS_BOOTSTRAP}{$getcv};
            }

            $output .= "    $j\n";

        }
        $output .= "\n}\n";

        $self->SUPER::add("${init_name}_${name}(aTHX);");
        ++$name;
    }

    $output .= "\nPERL_STATIC_INLINE int ${init_name}(pTHX)\n{\n";

    if ( $self->name eq 'init' ) {
        $output .= "    perl_init0(aTHX);\n";
    }
    $output .= $self->SUPER::output($format);
    $output .= "    return 0;\n}\n";
}

1;
