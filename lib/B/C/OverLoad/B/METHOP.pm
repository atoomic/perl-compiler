package B::METHOP;

use strict;

use B qw/cstring SVf_FAKE/;
use B::C::File qw( methopsect init init2 );
use B::C::Config;
use B::C::Helpers::Symtable qw/savesym/;
use B::C::Helpers qw/do_labels/;
use B::C::Save qw/savestashpv/;

sub do_save {
    my ( $op, $level ) = @_;

    $level ||= 0;

    my $name = $op->name || '';
    my $flagspv = $op->flagspv;

    my $union = $name eq 'method' ? "{.op_first=(OP*)%s}" : "{.op_meth_sv=(SV*)%s}";

    my $ix     = methopsect()->index + 1;
    my $rclass = $op->rclass->save("op_rclass_sv");
    if ( $rclass && $rclass =~ /^&sv_list/ ) {
        my $rclass_name = $op->rclass()->PV();
        my $sym         = savestashpv($rclass_name);
        if ( $sym && $sym =~ /^&sv_list/ ) {
            init()->sadd( "SvREFCNT_inc_simple_NN(%s); /* methop_list[%d].op_rclass_sv */", $rclass, $ix );
            init2()->sadd( "Perl_mro_method_changed_in((HV*) %s);  /* %s */", $sym, $rclass_name );
        }
    }
    my $first = $name eq 'method' ? $op->first->save : $op->meth_sv->save;

    if ( $first && $first =~ /^&sv_list/ ) {
        init()->sadd( "SvREFCNT_inc_simple_NN(%s); /* methop_list[%d].op_meth_sv */", $first, $ix );
    }

    methopsect()->comment_common("first, rclass");
    methopsect()->sadd( "%s, $union, (SV*)%s", $op->_save_common, $first, $rclass );
    methopsect()->debug( $name, $flagspv ) if debug('flags');
    my $sym = savesym( $op, "(OP*)&methop_list[$ix]" );    # save it before do_labels
    if ( $name eq 'method' ) {
        do_labels( $op, $level + 1, 'first', 'rclass' );
    }
    else {
        do_labels( $op, $level + 1, 'meth_sv', 'rclass' );
    }

    return $sym;
}

1;
