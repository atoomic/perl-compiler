package B::C::OP;

use strict;

use B qw/SVf_ROK/;
use B::C::Helpers::Symtable qw/savesym objsym/;

my $last;
my $count;
my $_stack;

sub save_constructor {

    # we cannot trust the OP passed to know which call we should call
    #   we are hardcoding it using a constructor for save
    my $for = shift or die;

    return sub {
        my ( $op, @args ) = @_;

        if (1) {    # infinite loop detection ( for debugging purpose)

            if ( $last && $last eq $op ) {
                ++$count;
                if ( $count == 10 ) {    # let's save a shorter stack to be able to detect it later
                    $_stack = sprintf(
                        "##### detect a potential infinite loop:\n%s - %s [ v=%s ] from %s\n",
                        ref $op,
                        $op,
                        ref $op eq 'B::IV' ? int( $op->IVX ) : "",
                        'B::C::Save'->can('stack_flat')->()
                    );

                    #die;
                }
                if ( $count == 10_000 ) {    # make this counter high enough to pass most of the common cases
                    print STDERR $_stack;
                }
            }
            else {
                $last  = "$op";
                $count = 1;
            }
        }

        # cache lookup
        {
            my $sym = objsym($op);
            return $sym if defined $sym;
        }

        # call the real save function and cache the return value{
        my $sym;

        # Any SV might be an RV actually so will save via the wrong package.
        my $class = $for;
        if ( ref($op) =~ m/^B::((PV(IV|LV|NV)?)|IV|NV|AV|GV|HV|CV|IO|FM)$/ && $op->FLAGS & SVf_ROK ) {
            $class = 'B::RV';
        }

        if (0) {    # Debug for tracking save paths.
            my @save_info = @args;
            if ( !@save_info ) {
                foreach my $try (qw/ppname FULLNAME SAFENAME NAME_HEK name NAME/) {
                    my $got;
                    if ( $class->can($try) && ( $got = $class->can($try)->($op) ) ) {
                        push @save_info, $got;
                    }
                    last if @save_info >= 2;
                }
                push @save_info, '' while scalar @save_info < 2;
            }
            print STDERR sprintf( "%s save for %s, %s\n", $class, $save_info[0], $save_info[1] );
        }
        eval { $sym = $class->can('do_save')->( $op, @args ); 1 }
          or die "$@\n:" . 'B::C::Save'->can('stack_flat')->();
        savesym( $op, $sym ) if defined $sym;
        return $sym;
    };

}

1;
