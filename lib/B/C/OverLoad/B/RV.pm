package B::RV;

use strict;

use B::C::Config;
use B::C::File qw/svsect init init2 init_static_assignments /;
use B::C::Helpers qw/is_constant/;

use B::C::Helpers::Symtable qw/objsym savesym/;

# Since 5.11 also called by IV::save (SV -> IV)
sub do_save {
    my ( $sv, $fullname ) = @_;
    $fullname ||= "(Unknown RV)";

    debug( sv => "Saving RV %s (0x%x) - called from %s:%s\n", ref($sv), $$sv, @{ [ ( caller(1) )[3] ] }, @{ [ ( caller(1) )[2] ] } );

    my ( $ix, $sym ) = svsect()->reserve($sv);
    svsect()->debug( $fullname, $sv );

    my $rv = $sv->RV->save($fullname);

    # 5.22 has a wrong RV->FLAGS (https://github.com/perl11/cperl/issues/63)
    my $flags = $sv->FLAGS;
    $flags = 0x801 if $flags & 9;    # not a GV but a ROK IV (21)

    svsect()->supdatel(
        $ix,
        '(void*)%s - sizeof(void*)' => $sym,              # the SvANY is set just below at init time
        '%Lu'                       => $sv->REFCNT + 1,
        '0x%x'                      => $flags,
        '{%s}', ( is_constant($rv) ? ".svu_rv=$rv" : "0 /* $rv */" )
    );

    my $update_sym = $sym;
    $update_sym =~ s/^&//;

    if ( !is_constant($rv) ) {
        my $init = ( $rv =~ /get_cv/ ) ? init2() : init();

        # check if the CV is bootsrrapped then use the correct section for it
        if ( my $sub = B::C::is_bootstrapped_cv($rv) ) {
            $init = B::C::get_bootstrap_section($sub);
        }

        # ref($rv) ne 'B::GV' && ref($rv) ne 'B::HV'
        $init->sadd( "%s.sv_u.svu_rv = (SV*)%s;", $update_sym, $rv );
    }

    return $sym;
}

1;
