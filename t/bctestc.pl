#!/usr/bin/perl

use strict;
use warnings;
use FindBin;

use Getopt::Std;
use Data::Dumper;

my $BC_TEST_DIR = $FindBin::Bin . "/v5.24.1/C-COMPILED/bctestc";

our $VERSION = 1;
my $github_issues_base = 'https://github.com/CpanelInc/perl-compiler/issues';

my %bugs = (
    '33' => [ 'PQR', 'sub c { caller(0) }  sub foo { package PQR; main->c() } print((foo())[0])' ],
);

my %opts;
getopts( 'hLX:', \%opts );

HELP_MESSAGE() if $opts{'h'};

if ( $opts{'L'} ) {
    mkdir $BC_TEST_DIR;
    chdir $BC_TEST_DIR or die("can't CD to $BC_TEST_DIR");

    opendir( DIR, $BC_TEST_DIR );
    while ( my $file = readdir DIR ) {
        unlink $file if -l $file;
    }
    closedir DIR;

    foreach my $test_id ( sort { $a <=> $b } keys %bugs ) {
        my $bug = $bugs{$test_id};
        if ( !$bug ) {
            print "No bug found for test ID '$test_id'\n";
            next;
        }
        ref $bug eq 'ARRAY' or die("Bug $test_id looks ill defined");

        my $bug_count = scalar @$bug;
        if ( $bug_count % 2 != 0 or $bug_count < 2 ) {
            die("There aren't an even amount of entries in the definition for bug $test_id");
        }

        my $subtest = 0;
        while (@$bug) {
            shift @$bug;
            shift @$bug;
            symlink( '../bctest.pl', sprintf( "%03d-%d.t", $test_id, $subtest ) );
            $subtest++;
        }
    }

    print "Symlinks setup for $BC_TEST_DIR\n";

    exit;
}

unshift @ARGV, $opts{'X'} if $opts{'X'};

foreach my $test_label (@ARGV) {
    my ( $test_id, $want_subtest ) = split( "-", $test_label );

    my $bug = $bugs{$test_id};
    if ( !$bug ) {
        print "No bug found for test ID '$test_id'\n";
        next;
    }
    ref $bug eq 'ARRAY' or die;

    print "$github_issues_base/$test_id\n\n";

    my $subtest = 0;
    while (@$bug) {
        my $result    = shift @$bug;
        my $perl_code = shift @$bug;
        next if defined $want_subtest && $want_subtest != $subtest;

        print "### Subtest $test_id-$subtest:\n";
        print "$perl_code\n";
        print "### RESULT: $result\n\n";
        $subtest++;
    }

}

exit 0;

exit;

sub VERSION_MESSAGE {
    print "$0 Version $VERSION\n";
    exit 1;
}

sub HELP_MESSAGE {
    print "$0 <opts> <bc testid>\n";
    print "\n";
    print "Description: This script tracks bugs reported via $github_issues_base\n";
    print "    Normally you would call it with a number and get back the code and what output is expected.\n";
    print "\n";
    print "optional arguments:\n";
    print "    -X<num>  print out tests related to <num>.\n";
    print "    -L       generate C_COMPILED tests and symlinks.\n";
    print "\n";
    print "    -h       print this help.\n";
    print "\n";
    exit 1;
}
