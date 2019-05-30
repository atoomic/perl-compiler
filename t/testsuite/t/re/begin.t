#!./perl
#
# This is a home for regular expression tests that are called in BEGIN
# and then later

use strict;
use warnings;
use 5.010;

sub run_tests;

$| = 1;

sub freeze_at_begin {
    my ($var) = @_;

    return $var =~ m{$var}o;
}

BEGIN {
    chdir 't' if -d 't';
    require Config;
    import Config;
    require './test.pl';
    require './charset_tools.pl';
    require './loc_tools.pl';
    set_up_inc( '../lib', '.', '../ext/re' );
    freeze_at_begin('frozen');
}
skip_all('no re module') unless defined &DynaLoader::boot_DynaLoader;
skip_all_without_unicode_tables();

plan tests => 2;    # Update this when adding/deleting tests.

run_tests() unless caller;

#
# Tests start here.
#
sub run_tests {

    {

        ok( !freeze_at_begin('not'),   "/o done at begin is preserved and a new string does not match" );
        ok( freeze_at_begin('frozen'), "/o done at begin is preserved and the original string matches" );

    }

}    # End of sub run_tests

1;

#
# ex: set ts=8 sts=4 sw=4 et:
#
