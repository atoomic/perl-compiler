#!perl -w

use strict;
use warnings;

use Test2::Bundle::Extended;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;

use FileHandle;

use B::C::InitSection;

my %symtable;

my $initsection = B::C::InitSection->new( 'my_init_section', \%symtable, 0 );

ok !$initsection->has_values(), "no values added to the section";

$initsection->add("int i = 42;");
ok $initsection->has_values(), "section has one value";

is $initsection->output, <<'EOS', "basic rendering for one init section";
static void perl_my_init_section_aaaa(pTHX)
{
    int i = 42;

}

PERL_STATIC_INLINE int perl_my_init_section(pTHX)
{
    perl_my_init_section_aaaa(aTHX);
    return 0;
}
EOS

my $another_section = B::C::InitSection->new( 'another', \%symtable, 0 );
ok !$another_section->has_values(), "no values added to the section";

$another_section->add_initav("register int i;");

ok !$another_section->has_values(), "section has no values: only header set";

done_testing();
