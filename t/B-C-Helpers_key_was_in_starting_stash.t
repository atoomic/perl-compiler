#!perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use B::C::Helpers qw/key_was_in_starting_stash/;

our $stash = {};

package B::C {
    our $settings->{'starting_stash'} = $main::stash;
}

$stash->{'File::'}->{'Stash::'} = { ISA  => 1 };
$stash->{'foo'}                 = 1;
$stash->{'Funny::'}->{'Var::'}  = { BOOP => 1 };
$stash->{'Very::'}->{'Deep::'}->{'Path::'}->{'Is::'}->{'here'} = 1;
$stash->{'Other::'} = ['wtf'];

#diag explain $stash;

like( dies { key_was_in_starting_stash() },   qr/^no stash for key_was_in_starting_stash at /, "Nothing passed to key_was_in_starting_stash dies" );
like( dies { key_was_in_starting_stash('') }, qr/^no stash for key_was_in_starting_stash at /, "Empty string passed to key_was_in_starting_stash dies" );
like( dies { key_was_in_starting_stash(0) },  qr/^no stash for key_was_in_starting_stash at /, "0 passed to key_was_in_starting_stash dies" );

is( key_was_in_starting_stash('main::'),   1, "main:: was present of course!" );
is( key_was_in_starting_stash('main::::'), 0, "Extra colons breaks. Probably a bug in FULLNAME" );

#is (key_was_in_starting_stash('main::'), 0, "Not even sure what main:: would imply for a presence check.");

present('File::Stash::');
missing('File::Stash');
missing('File::Staff::');

present('File::Stash::ISA');
missing('File::Stash::ISAP');
missing('File::Stash::SA');

missing('Funny::Var::NotHere');
missing('Funny::Var::NotHere::');

present('Funny::Var::');
missing('Funny::Var::::');
missing('::Funny::Var::');

present('Very::Deep::Path::Is::here');
missing('Very::Deep::Path::here');
missing('Very::Deep::Path::Is::Not::here');

missing('Other::Path::Is::Bad');

#like(dies{key_was_in_starting_stash('Funny::wtf')}, qr/fff/, "Invalid stash tree detected causes a die;");
done_testing();

sub present {
    my $path = shift or die;

    is( key_was_in_starting_stash($path),              1, "$path is present" );
    is( key_was_in_starting_stash( 'main::' . $path ), 1, "main::$path is present" );
}

sub missing {
    my $path = shift or die;

    is( key_was_in_starting_stash($path),              0, "$path is missing" );
    is( key_was_in_starting_stash( 'main::' . $path ), 0, "main::$path is missing" );
}

exit;
