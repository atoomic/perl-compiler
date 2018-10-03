#!perl

use B();
use strict;
use warnings;

use POSIX;    # load many KEYS

INIT {
    # manually load B::C xs code
    require XSLoader;
    no warnings q/once/;
    XSLoader::load('B::C');
}

exit( test() // 0 ) unless caller;

sub test {

    print "1..2\n";    # out test plan;

    # get access to strtab
    my $strtab = 'B::C'->can('strtab')->();

    # read the hash stats into a hash
    my $h_stats = peek_as_hash($strtab);

    #print dumper( $h_stats ); # always display stats

    # check that we have enough keys
    ok( int( $h_stats->{'KEYS'} ) > 1000, "strtab has more than 1000 keys" );    # or dumper($h_stats);

    # check that hash quality
    ok( int( $h_stats->{'hash quality'} ) > 85, "strtab 'hash quality' is greater than 85%" );    # or dumper($h_stats);

    print dumper($h_stats);                                                                       # always display stats

    return;
}

my $counter = 0;

sub ok {
    my ( $ok, $msg ) = @_;

    ++$counter;
    $msg //= '';

    my $not = $ok ? '' : 'not ';

    print "${not}ok $counter - $msg\n";

    return $ok;
}

sub dumper {
    my ($content) = @_;

    eval q/use Test::More/;
    eval q/note explain $content/;

    return;
}

sub peek_as_str {
    my ($in) = @_;

    # lazy load Devel::Peek
    eval q/use Devel::Peek; 1/ or die "failed to load Devel::Peek";

    #local *STDERR;
    # redirect stderr to a scalar
    close(STDERR);
    my $stderr;
    open STDERR, '>', \$stderr;
    'Devel::Peek'->can('Dump')->( $in, 1 );    # SEGV without setting recursion limit

    return $stderr;
}

sub peek_as_hash {
    my ($in) = @_;

    my $peek = peek_as_str($in);

    my $h_stats = {};
    my @lines = split( /\n/, $peek );
    foreach my $line (@lines) {
        $line =~ s{^\s+}{};
        $line =~ s{\s+$}{};
        my ( $k, $v ) = split( '=', $line, 2 );

        $k =~ s{\s+$}{};
        $v =~ s{^\s+}{};

        $h_stats->{$k} = $v;
    }

    return $h_stats;
}
