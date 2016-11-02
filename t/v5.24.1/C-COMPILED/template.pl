#!perl

use strict;
use warnings;

use Cwd;
use File::Basename;
use Test::More;

BEGIN {
    use FindBin;
    unshift @INC, $FindBin::Bin . "/../../../lib";
}

die "Please use perl 5.24" unless $^V =~ qr{^v5.24};

# Some tests need . in @INC.
$ENV{'PERL_USE_UNSAFE_INC'} = 1;

use KnownErrors qw/check_todo/;
use TestCompile qw/compile_script/;

if ( $0 =~ m{/template\.pl$} ) {
    plan q{skip_all} => "This program is not designed to be called directly";
    exit;
}

my $optimization = '';
$optimization .= '-v,'     if ( $ENV{VERBOSE} );
$optimization .= '-Dwalk,' if ( $ENV{BC_WALK} );

# Setup file_to_test to be the file we actually want to test.
my ( $file_to_test, $path ) = fileparse($0);
my ( $before, $after ) = split( 'C-COMPILED/', $path );
my $short_path = $path;
$short_path =~ s{^.*C-COMPILED/+}{};
$file_to_test = $short_path . $file_to_test;

# The file that tracks acceptable failures in the compiled unit tests.
my $known_errors_file = "known_errors.txt";

my $errors = KnownErrors->new( file_to_test => $file_to_test );

# The relative path our symlinks will point to.
my $base_dir = dirname($path);

my $cwd = qx{pwd};
chomp $cwd;

chdir "$FindBin::Bin/../" or die $!;

my $current_t_file   = $file_to_test;
my $todo_description = '';

my $type = $errors->get_current_error_type();
$todo_description = $errors->{todo_description} if $type;

# Skip this test all together if $type is SKIP or COMPAT
if ( $type eq 'COMPAT' || $type eq 'SKIP' ) {
    plan skip_all => $todo_description;
}

# need to run CORE test suite in t
chdir "$FindBin::Bin/../../t" or die "Cannot chdir to t directory: $!";

plan tests => 12;

ok( !-z $file_to_test, "$file_to_test exists" );
open( my $fh, '<', $file_to_test ) or die("Can't open $file_to_test");
my $taint = <$fh>;
close $fh;
$taint = ( ( $taint =~ m/\s\-w?T/ ) ? '-T' : '' );
pass( $taint ? "Taint mode!" : "Not in taint mode" );

( my $c_file   = $file_to_test ) =~ s/\.t$/.c/;
( my $bin_file = $file_to_test ) =~ s/\.t$/.bin/;
unlink $bin_file, $c_file;

my $PERL = $^X;
my $blib = ( grep { $_ =~ m{/blib/} } @INC ) ? '-Mblib' : '';

my $check = `$PERL -c $taint '$file_to_test' 2>&1`;
like( $check, qr/syntax OK/, "$PERL -c $taint $file_to_test" );

$ENV{HARNESS_NOTTY} = 1;

TODO: SKIP: {
    local $TODO;

    $errors->{to_skip} = 9;

    # shared logic with testc
    my ( $parser, $errormsg ) = compile_script(
        $file_to_test, $errors,
        {
            extra        => $taint,
            optimization => $optimization,
            c_file       => $c_file,
            bin_file     => $bin_file,

        }
    );

    # handle error when compiling script
    skip $errormsg, $errors->{to_skip} unless $parser;

    my $tests_ok = $errors->check_todo( $parser->{exit} == 0, "Exit code is $parser->{exit}", "EXIT" );
    $tests_ok = $errors->check_todo( !scalar @{ $parser->{failed} }, "Test results:", 'TESTS' ) && $tests_ok;
    if ( length $parser->{out} < 1_000_000 ) {
        print "    $_\n" foreach ( split( "\n", $parser->{out} ) );
    }
    else {
        diag("Output is too long to display. Skipping.");
    }

    unless ($tests_ok) {
        note( "Failed tests: " . join( ", ", @{ $parser->{failed} } ) );
        skip "tests are failing", $errors->{to_skip};
    }

    $errors->check_todo( !scalar @{ $parser->{parse_errors} }, "Tests are in sequence", 'SEQ' )
      or do {
        note explain $parser->{parse_errors};
        skip "tests are not in sequence", $errors->{to_skip};
      };

    $errors->check_todo( !scalar @{ $parser->{todo_passed} }, "No TODO tests passed", 'TODO' )
      or note( "TODO Passed: " . join( ", ", @{ $parser->{todo_passed} } ) );
}

unlink $bin_file, $c_file unless $ENV{BC_DEVELOPING};

if ( $ENV{BC_DEVELOPING} ) {
    note "List of generated files for ", $file_to_test;

    # add the list of files generated
    my $root = $FindBin::Bin;
    $root =~ s{^$cwd}{};
    $root =~ s{C-COMPILED}{t};
    my @path = split( '/', $root );
    pop @path;
    $root = join '/', @path;
    $root =~ s{^/+}{};

    ( my $look_for = $file_to_test ) =~ s/\.t$//;

    foreach my $f ( sort glob("$look_for*") ) {
        note "$root/$f" if -e $f;
    }
}

exit;
