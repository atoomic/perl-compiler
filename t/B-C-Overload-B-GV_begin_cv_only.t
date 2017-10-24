
use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use File::Temp;
use File::Slurp qw{write_file};

my $perlcc = qx{which perlcc}; # $^X . cc
chomp $perlcc;
note "Using perlcc: ", $perlcc;

my $tmp = File::Temp->newdir( "BC-test-XXXXXXX", TMPDIR => 1, DIR => $ENV{HOME}, CLEANUP => 0 );
my $tmpdir = $tmp->dirname;

note "Temporary directory is: ", $tmpdir;
chdir $tmpdir or die "Cannot chdir to $tmpdir";
foreach my $BLOCK ( qw{BEGIN CHECK UNITCHECK } ) {
	note "==== Testing compilation of $BLOCK block";
	my $tmpfile = $tmpdir . "/test-$BLOCK.pl";
	my $binfile  =  $tmpdir . "/test-$BLOCK";
	my $cfile  =  $tmpdir . "/test-$BLOCK";
	my $code = <<"EOS";
our \$var;
$BLOCK {
	\$var = 42;
	print STDERR "# this is my custom block $BLOCK\n";
}
print q[ok] if \$var == 42;
EOS
	ok write_file( $tmpfile, $code );;
	qx{$^X -c $tmpfile};
	is $?, 0, "perl -c succeeds";

	note "Compiling $tmpfile";
	my $out;
	note qq{$perlcc -o $binfile -S $tmpfile 2>&1};;
	$out = qx{$perlcc -o $binfile -S $tmpfile 2>&1};
	is $?, 0, "compile succeeds" or diag $out;
	ok -x $binfile, "filebin created" or die;
	$out = qx{$binfile};
	is $out, "ok", "binary returns 1";

	ok -e $cfile, "c file created" or die;
	$out = qx{grep -c "this is my custom block $BLOCK" $cfile};
	my $count = int($out);
	is $count, 0, "Cannot find block content from c source code";

}

done_testing;