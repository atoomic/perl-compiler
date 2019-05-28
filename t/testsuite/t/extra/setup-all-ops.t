#!./perl

BEGIN {
	*B::C::SETUP_ALL_OPS = sub { 1 } # ask for preset all OPs
}

=pod

Try several OPs using the SETUP_ALL_OPS mode

=cut

print "1..8\n"; # plan

ok( 1 == 1, "1 == 1" );
my $a = q[abcd];
my $b = qq[abcd\n];
chomp $b;

ok( $a eq $b, "chomp + eq" );

my $x = q[ababab];
$x =~ s{a}{x}g;
ok( $x eq q[xbxbxb], "x eq xbxbxb: $x" );

my $abc = q[ABC];
my $another = $abc;
$abc .= "xyz";
ok( $abc ne $another, "abc ne another" );
ok( $abc eq 'ABCxyz', "abc eq ABCxyz" );

ok( -e $0, "$0 file exists" );

{
	# try a custom OP now
	use Ref::Util::XS ();

	ok( Ref::Util::XS::is_arrayref( [] ), "is_arrayref []" );
	ok( !Ref::Util::XS::is_arrayref( {} ), "! is_arrayref {}" );
}

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