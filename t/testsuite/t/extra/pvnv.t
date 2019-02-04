#!./perl

eval q{use Devel::Peek};

print "1..14\n";

{
    note("a - a simple NV");
    my $A;
    BEGIN { $A = $] + 0.0000000001 }

    my $dump = mydump($A);

    like( $dump, qr{\bSV = NV\b}, "regular NV" );
}

{
    note("b - PVNV downgraded as IV");
    my $B;
    BEGIN { $B = 'txt'; $B += 42; }

    my $dump = mydump($B);

    if ( is_compiled() ) {
        like( $dump, qr{\bSV = IV\b}, "IV compiled" );
        like( $dump, qr{IV = 42},     "value" );
    }
    else {
        like( $dump, qr{\bSV = PVNV\b}, "PVNV uncompiled" );
        like( $dump, qr{NV = 42},       "value" );
    }
}

{
    note("c - Downgrade one PVNV with NOK");
    my $C;

    BEGIN {
        $C = 4.2;
        $C = "wert";    # NV upgraded as PVNV
        $C = 4.5;       # then go back to nOK
    }

    my $dump = mydump($C);

    if ( is_compiled() ) {
        like( $dump, qr{\bSV = NV\b}, "NV compiled" );
        like( $dump, qr{NV = 4\.5},   "value" );
    }
    else {
        like( $dump, qr{\bSV = PVNV\b}, "PVNV uncompiled" );
        like( $dump, qr{NV = 4\.5},     "value" );
    }
}

{
    note("d - downgrade PVNV as a regular NV at compilation");
    my $x;
    my $D;

    BEGIN {
        $D = 4.2;
        $x = "upgrade variable d to PVNV $D";
    }

    my $dump = mydump($D);

    ok( $D == 4.2, 'check value' );

    if ( is_compiled() ) {

        like( $dump, qr{\bSV = NV\b}, "NV compiled" );
        like( $dump, qr{NV = 4\.2},   "value" );
    }
    else {
        like( $dump, qr{\bSV = PVNV\b}, "PVIV uncompiled" );
        like( $dump, qr{NV = 4\.2},     "value" );
    }
}

{
    note("e - do not downgrade a PVNV to an NV when pPOK");
    my $E;

    BEGIN {
        $E = 1.2345;
        $E .= "";
    }

    my $dump = mydump($E);

    # if ( is_compiled() ) {
    #     like( $dump, qr{\bSV = NV\b}, "downgrade as a NV" );
    #     like( $dump, qr{NV = 1\.2345}, "value" );
    # }
    # else {
    like( $dump, qr{\bSV = PVNV\b},   "PVNV uncompiled" );
    like( $dump, qr{PV =.+"1\.2345"}, "value" );

    #}
}

{
    note("f - do not downgrade a PVNV to an NV when using extra 0 padding");

    # problem this is the same case as previously
    my $F;

    BEGIN {
        $F = '1.2345000';
        $F *= 1;
        $F = '1.2345000';

        # This is creating a PVNV
        #   NV = 1.2345
        #   PV = 0x7b7660 "1.2345000"\0
    }

    my $dump = mydump($F);

    if ( is_compiled() ) {
        like( $dump, qr{\bSV = PVNV\b},      "PVNV uncompiled" );
        like( $dump, qr{NV =.+0\b},          "NV value [not saved]" );
        like( $dump, qr{PV =.+"1\.2345000"}, "PV value" );
    }
    else {
        like( $dump, qr{\bSV = PVNV\b},      "PVNV uncompiled" );
        like( $dump, qr{NV =.+1\.2345\b},    "NV value" );
        like( $dump, qr{PV =.+"1\.2345000"}, "PV value" );
    }
}

{
    our $zero;

    BEGIN {
        $zero = 1.23;
        $zero = "0" . $zero;
    }

    sub ZERO { $zero }

    ok( ZERO() eq '01.23', "PVNV '0123' is not downgraded to NV" );
}

exit;

# ... helpers ....

sub is_compiled {
    return $0 =~ qr{\.bin$} ? 1 : 0;
}

my $closed;

my $out;

sub mydump {
    $out = '';

    close STDERR;
    {
        local *STDERR;
        open STDERR, ">", \$out;

        Dump( $_[0] );
        note("[ $out ]");
    }

    return $out;
}

{
    my $_counter = 0;

    sub ok {
        my ( $t, $msg ) = @_;

        $msg ||= '';
        ++$_counter;

        if ($t) {
            print "ok $_counter - $msg\n";
            return 1;
        }
        else {
            print "not ok $_counter - $msg\n";
            return 0;
        }
    }
}

sub like {
    my ( $s, $re, $msg ) = @_;

    if ( defined $re ) {
        my $ok = $s =~ $re ? 1 : 0;
        return ok( $ok, $msg );
    }

    die;
}

sub note {
    my $s = shift;
    return unless defined $s;
    map { print "# $_\n" } split( qr{\n}, $s );    # map in void context, yea

    return;
}
