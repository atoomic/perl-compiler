#!./perl

print "1..1\n";

use utf8;
#use open qw( :utf8 :std );
#no warnings 'once';

my $refee = bless [], "\x{100}a";

my $string = $refee;
$string = "$string";
# at this stage the string looks ok...
#eval q{use Devel::Peek; Dump $string};
substr $refee, 0, 0, "\xff";
my $expect = "\xff$string";
#eval q{use Devel::Peek; Dump "$refee"; Dump $expect};

print "$refee" eq $expect ? "ok 1\n" : "not ok 1\n";

1;
