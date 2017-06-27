#!/usr/bin/env perl

# cpanel - t/bctestc.pl                               Copyright 2017 cPanel, Inc.
#                                                            All rights Reserved.
# copyright@cpanel.net                                          http://cpanel.net
# This code is subject to the cPanel license.  Unauthorized copying is prohibited

use strict;
use warnings;
use FindBin;

use Getopt::Std;
use Data::Dumper;
use File::Slurp qw{read_file};

our $VERSION = 1.01;

use constant DEFAULT_OUTPUT => qq{ok\n};

my $BC_TEST_DIR = $FindBin::Bin . "/v5.24.1/C-COMPILED/bctestc";
my $BC_TEST_T_DIR = $FindBin::Bin . q{/v5.24.1/t/bctestc};

my $github_issues_base = 'https://github.com/CpanelInc/perl-compiler/issues';

my $bugs = find_all_tests();

my %opts;
getopts( 'hLX:', \%opts );

HELP_MESSAGE() if $opts{'h'} || ( ! scalar @ARGV && !scalar keys %opts );

if ( $opts{'L'} ) {
    mkdir $BC_TEST_DIR;
    chdir $BC_TEST_DIR or die("can't CD to $BC_TEST_DIR");

    opendir( DIR, $BC_TEST_DIR );
    while ( my $file = readdir DIR ) {
        unlink $file if -l $file;
    }
    closedir DIR;

    foreach my $test_id ( sort { $a <=> $b } keys %$bugs ) {
        my $bug = $bugs->{$test_id};
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

    my $bug = $bugs->{$test_id};
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
        next if defined $want_subtest && $want_subtest != $subtest++;

        # lazy load the content on demand
        $result = $result->() if ref $result eq 'CODE';
        $perl_code = $perl_code->() if ref $perl_code eq 'CODE';

        print "### Subtest $test_id-$subtest:\n";
        print "$perl_code\n";
        print "### RESULT: $result\n\n";
    }

}

exit 0;

sub find_all_tests {
    my $bugs = {};

    die "Cannot chdir to $BC_TEST_T_DIR: $!" unless -d $BC_TEST_T_DIR;

    my @all_tests = glob("$BC_TEST_T_DIR/*.t");
    die "No tests" unless scalar @all_tests;

    my $custom_output = { map { $_ => 1 } glob("$BC_TEST_T_DIR/*.out") };

    foreach my $file ( @all_tests ) {
        my $t = $file;
        $t =~ s{^$BC_TEST_T_DIR/}{};
        if ( $t =~ qr{^([0-9]+)\.} ) {
            my $id = $1;

            my $expect = DEFAULT_OUTPUT;
            my $load_t_content = sub { return scalar read_file( $file ) };
            my $custom_output_file = $file;
            $custom_output_file =~ s{\.t$}{\.out};
            if ( $custom_output->{ $custom_output_file } ) {
                $expect = sub { return scalar read_file( $custom_output_file ) };
            }

            # push the test
            $bugs->{$id} //= [];
            push $bugs->{$id}->@*, $expect, $load_t_content;
        }
    }

    return $bugs;
}

sub VERSION_MESSAGE {
    print "$0 Version $VERSION\n";
    exit 1;
}

sub HELP_MESSAGE {



print <<"EOS";
$0 <opts> <bc testid>

* Description: This script tracks bugs reported via $github_issues_base
    Normally you would call it with a number and get back the code and what output is expected.

* optional arguments:
    -X<num>  print out tests related to <num>.
    -L       generate C_COMPILED tests and symlinks.

    -h       print this help.

* Sample usages:

    # print test for a github id
    $0 -X 36
    $0 36

    # update all symlinks
    $0 -L

* Tests Cookbook:

    All tests are located in the directory:
    $BC_TEST_T_DIR
    They are named ID(.SUBTEST)?.t using the following conventions

    ID      - is a the github numerical id of the bug
    SUBTEST - any alphanumerical identifier for the subtest [optional]

    The default output for a test is "ok\n" but can be customized by providing
    a ID(.SUBTEST)?.out which match the test.

EOS
    exit 1;
}