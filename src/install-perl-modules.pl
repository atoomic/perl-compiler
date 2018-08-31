#!/usr/local/cpanel/3rdparty/bin/perl

use strict;
use warnings;

use FindBin ();
use Test::More;

my @TARBALLS = qw{
    inc-latest-0.500.tar.gz
    Module-Build-0.4224.tar.gz
    App-cpanminus-1.7044.tar.gz
    Test-Simple-1.302140.tar.gz
};

my @Modules = qw{
    XML::Parser
    TAP::Formatter::JUnit

    Test2::Bundle::Extended
    Test::Trap
    Test2::Tools::Explain
    Test::Deep
    Test2::Plugin::NoWarnings

    B::Flags
    Capture::Tiny
    Template::Toolkit

    EV
    IO::Socket::SSL
    IO::Socket::INET6
    JSON::XS
    Net::SSLeay
    Net::DNS
    Net::LibIDN

};

run() unless caller;

sub run {

    my $start = $FindBin::Bin;

    note "start: ", $start;

    note explain \@TARBALLS;
    foreach my $tarball (@TARBALLS) {
        note $tarball;
        die qq[Fail to install perl module $tarball\n]
            unless install_tarball($tarball);

        chdir($start);
    }

    $ENV{PATH}
        = '/usr/local/cpanel/3rdparty/perl/528/bin/:/opt/cpanel/perl5/528/bin:'
        . $ENV{PATH};

    my $cpanm = qx{which cpanm};
    chomp $cpanm if $cpanm;
    die unless $cpanm && -x $cpanm;
    foreach my $module (@Modules) {

        note "==> install $module via cpanm";
        my $cmd = "$^X $cpanm -v --force --notest $module 2>&1";
        my $out;
        $out = qx{$cmd};

        #next if $module eq 'Test2::Bundle::Extended';
        do { diag "*** cpanm failure for $module\n$out\n**********"; next } unless $? == 0;

        next if $module =~ qr{^\.};

        my $out = qx{$^X -M$module -e1 2>&1};

        if ( $? == 0 ) {
        	note "===> module $module installed via cpanm...";
        } else {
        	diag "installation failed for module module: :", $module, 
        		" using cpanm # $^X -M$module -e1", "\n", $out;
        } 
    }

    #install_tarball("Test2-Suite-0.000115.tar.gz");

    return;
}

sub install_tarball {
    my ($tarball) = @_;

    note "installing $tarball";
    my $dir = $tarball;

    if ( -d $dir ) {
        note "removing $dir";
        qx{rm -rf $dir};
    }

    system(qq{tar xvzf $tarball}) == 0 or return;

    $dir =~ s{\Q.tar.gz\E$}{};

    chdir($dir) or do { diag "failed to chdir: $!"; return };

    my @CMDS;

    if ( -e 'Makefile.PL' ) {
        note 'Makefile.PL';
        @CMDS = (
            qq{$^X Makefile.PL INSTALLDIRS=vendor},
            qq{make},

            #qq{make test},
            qq{make install},
        );
    }
    elsif ( -e 'Build.PL' ) {
        note 'Build.PL';
        @CMDS = (
            qq{$^X Build.PL},
            qq{./Build},

            #qq{./Build test},
            qq{./Build install},
        );
    }
    else {

        die q[no Build.PL or Makefile.PL];
    }

    foreach my $cmd (@CMDS) {
        note "RUN: $cmd";
        my $out = qx{$cmd 2>&1};
        if ( $? != 0 || $out =~ qr{^ERROR} )
        {    # Build do not set the status code correctly
            diag "failed to run $cmd\n", $out;
            return;
        }
    }

    return 1;
}
