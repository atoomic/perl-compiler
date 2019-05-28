#!./perl

# force to use the XS module for test
use Ref::Util::XS ();

my $array = [];
my $int   = 42;
my $svref = \$int;
my $hash  = {};
my $code  = sub { 42 };

print "1..20\n";

# is_arrayref
ok( Ref::Util::XS::is_arrayref($array),  "[] is an ARRAY ref" );
ok( !Ref::Util::XS::is_arrayref($int),   "42 is not an ARRAY ref" );
ok( !Ref::Util::XS::is_arrayref($svref), "svref is not an ARRAY ref" );
ok( !Ref::Util::XS::is_arrayref($hash),  "hash is not an ARRAY ref" );
ok( !Ref::Util::XS::is_arrayref($code),  "code is not an ARRAY ref" );

# is_hashref
ok( !Ref::Util::XS::is_hashref($array), "[] is not a HASH ref" );
ok( !Ref::Util::XS::is_hashref($int),   "42 is not a HASH ref" );
ok( !Ref::Util::XS::is_hashref($svref), "svref is not a HASH ref" );
ok( Ref::Util::XS::is_hashref($hash),   "hash is a HASH ref" );
ok( !Ref::Util::XS::is_hashref($code),  "code is not a HASH ref" );

# is_coderef
ok( !Ref::Util::XS::is_coderef($array), "[] is not a CODE ref" );
ok( !Ref::Util::XS::is_coderef($int),   "42 is not a CODE ref" );
ok( !Ref::Util::XS::is_coderef($svref), "svref is not a CODE ref" );
ok( !Ref::Util::XS::is_coderef($hash),  "hash is not a CODE ref" );
ok( Ref::Util::XS::is_coderef($code),   "code is a CODE ref" );

# is_scalarref
ok( !Ref::Util::XS::is_scalarref($array), "[] is not a SCALAR ref" );
ok( !Ref::Util::XS::is_scalarref($int),   "42 is not a SCALAR ref" );
ok( Ref::Util::XS::is_scalarref($svref),  "svref is not a SCALAR ref" );
ok( !Ref::Util::XS::is_scalarref($hash),  "hash is not a SCALAR ref" );
ok( !Ref::Util::XS::is_scalarref($code),  "code is a SCALAR ref" );

exit;

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
