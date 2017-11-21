#!perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Subtest;

use Capture::Tiny ':all';

use File::Temp;


my $tmp = File::Temp->newdir( "BC-POSIX-test-XXXXXXX", TMPDIR => 1, DIR => $ENV{HOME}, CLEANUP => 1 );
my $dir = $tmp->dirname;

ok chdir($dir), "chdir"; # note: bc do not support full path in -o file...

my $binary_utf8  = "bc-binary-utf8";
my $binary_C     = "bc-binary-C";

my $PATH = $ENV{PATH}; # need to preserve it

my $perlcc = $^X . q{cc}; # perlcc
note "Using perlcc: ", $perlcc;
die "cannot find bc binary" unless -x $perlcc;

my $oneliner = q[use warnings; BEGIN { $POSIX::MB_CUR_MAX =1 }; use POSIX ();  print POSIX::MB_CUR_MAX() ];

my ( $stdout, $stderr );

{
	note "compile with LC_ALL=LANG=en_US.UTF-8";
	local %ENV;
	set_env_for_us_utf8();

	( $stdout, $stderr ) = capture \&run_uncompiled;
	is $stdout, 6, "MB_CUR_MAX = 6 when using LC_ALL=en_US.UTF-8";
	is $stderr, '', "nothing on stderr";

	compile_oneliner_to( $binary_utf8 );

}

{
	note "compile with LC_ALL=C";
	local %ENV;
	set_env_without_locale();

	# check the uncompiled version
	( $stdout, $stderr ) = capture \&run_uncompiled;
	is $stdout, 1, "MB_CUR_MAX = 1 when all locale are unset";
	is $stderr, '', "nothing on stderr";

	compile_oneliner_to( $binary_C );
}

# now testing
my %tests = (
	'en_US.UTF-8' => \&set_env_for_us_utf8,
	'LC_ALL=C' => \&set_env_without_locale,
);

foreach my $locale ( sort keys %tests ) {
	local %ENV;
	note "setting locale for $locale";
	$tests{$locale}->();

	( $stdout, $stderr ) = capture { system "./${binary_utf8}" };
	is [ $stdout, $stderr ] => [ 6, '' ], "running binary_utf8 with ENV set for $locale";

	( $stdout, $stderr ) = capture { system "./${binary_C}" };
	is [ $stdout, $stderr ] => [ 1, '' ], "running binary_C with ENV set for $locale";
}

ok chdir('/tmp'), 'chdir /tmp'; # require to purge the tmp directory


done_testing();
exit;

sub set_env_for_us_utf8 {
	$ENV{LANG} = $ENV{LC_ALL} = q[en_US.UTF-8];
	# required or gcc will fail with "collect2: fatal error: cannot find 'ld'"
	$ENV{PATH} = $PATH;
	return;
}

sub set_env_without_locale {
	$ENV{LC_ALL} = 'C';
	# required or gcc will fail with "collect2: fatal error: cannot find 'ld'"
	$ENV{PATH} = $PATH;

	return;
}

sub compile_oneliner_to {
	my $out = shift // 'a.out';

	note "compiling $out...";

	unlink $out if -e $out; # protection
	ok !-e $out, "binary not available";
	my $status;
	note qq[$perlcc -o$out -e '$oneliner'];
	my ($stdout, $stderr, $exit) = capture { system qq[$perlcc -o$out -e '$oneliner']; $status = $? };
	is $status, 0, "perlcc compiled $out";
	ok -x $out, "compiled binary $out is available";

	return;
}

sub run_uncompiled {
	system qq{$^X -e '$oneliner'}
};
