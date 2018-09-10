#!/usr/local/cpanel/3rdparty/bin/perl

use strict;
use warnings;

use FindBin ();
use Test::More;

our $CWD;

BEGIN {
    $CWD = $FindBin::Bin;
}

# list of tarballs to install
my @TARBALLS = qw{

    inc-latest-0.500.tar.gz
    Module-Build-0.4224.tar.gz
    Test-Simple-1.302140.tar.gz

    App-cpanminus-1.7044.tar.gz

};

# force to install some modules
my $FORCE = { map { $_ => 1 } qw{Test::Simple} };

# list of modules installed using cpanm
# should move them to a cpanfile
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
    DBI
    DBD::SQLite
    Moose
    IO::Scalar

};

run() unless caller;

sub run {

    # make sure we are run using the perl528
    if ( $] < 5.028 ) {
        note "Using perl528 to rerun this script";
        exec '/usr/local/cpanel/3rdparty/perl/528/bin/perl', $0;
    }

    # setup env
    delete $ENV{PERL5LIB};

    $ENV{PATH}
        = '/usr/local/cpanel/3rdparty/perl/528/bin/:/opt/cpanel/perl5/528/bin:'
        . $ENV{PATH};

    note "== START == $0 at ", scalar localtime();
    install_perl_modules();
    note "== END == $0 at ", scalar localtime();

    return;
}

sub install_perl_modules {

    _install_tarballs();
    _install_using_cpanm();

    patch_modules();

    return;
}

sub _install_using_cpanm {

    my $cpanm = qx{which cpanm};

    chomp $cpanm if $cpanm;
    die unless $cpanm && -x $cpanm;

    foreach my $module (@Modules) {
        my $out;

        if ( !$FORCE->{$module} && eval qq{require $module; 1} ) {
            note "==> module $module is already available";
            next;
        }

        note "==> installing $module via cpanm",
            $FORCE->{$module} ? ' [force]' : '';
        my $cmd = "$^X $cpanm -v --force --notest $module 2>&1";

        $out = qx{$cmd};

        #next if $module eq 'Test2::Bundle::Extended';
        do { diag "*** cpanm failure for $module\n$out\n**********"; next }
            unless $? == 0;

        next if $module =~ qr{^\.};

        $out = qx{$^X -M$module -e1 2>&1};

        if ( $? == 0 ) {
            note "module $module installed via cpanm...";
        }
        else {
            diag "installation failed for module module: :", $module,
                " using cpanm # $^X -M$module -e1", "\n", $out;
        }
    }

    chdir($CWD);

    return;
}

sub _install_tarballs {

    foreach my $tarball (@TARBALLS) {
        note $tarball;
        die qq[Fail to install perl module $tarball\n]
            unless install_from_tarball($tarball);

        chdir($CWD);
    }

    return;
}

sub patch_modules {

    # TAP::Formatter::JUnit::Session
    my $session = qx{$^Xdoc -l TAP::Formatter::JUnit::Session};
    die "cannot find TAP::Formatter::JUnit::Session" unless length $session;
    chomp $session;

    qx{cp Session.pm $session};

    note "TAP::Formatter::JUnit::Session patched: ",
        $? == 0 ? 'ok' : 'not ok';

    # DBD::SQLite
    my $dbd_sqlite = qx{perldoc -l DBD::SQLite};
    if ($dbd_sqlite) {
        chomp $dbd_sqlite;
        my $c = qx{grep -c XSLoader $dbd_sqlite};
        chomp $c;
        if ( $c == 0 ) {
            my $out
                = qx{patch -i DBD-SQLite-0002-use-XSLoader.patch $dbd_sqlite 2>&1};
            if ( $? == 0 ) {
                note "Patched DBD::SQLite: $dbd_sqlite";
            }
            else {
                diag "Failed to patch DBD::SQLite:\n", $out;
            }
        }
    }

    return;
}

sub install_from_tarball {
    my ($tarball) = @_;

    note "==> Installing $tarball from tarball";
    my $dir = $tarball;

    if ( -d $dir ) {
        note "removing $dir";
        qx{rm -rf $dir};
    }

    system(qq{tar xvzf $tarball >/dev/null}) == 0 or return;

    $dir =~ s{\Q.tar.gz\E$}{};

    chdir($dir) or do { diag "failed to chdir: $!"; return };

    my @CMDS;

    if ( -e 'Makefile.PL' ) {
        note 'using Makefile.PL';
        @CMDS = (
            qq{$^X Makefile.PL INSTALLDIRS=vendor},
            qq{make},

            #qq{make test},
            qq{make install},
        );
    }
    elsif ( -e 'Build.PL' ) {
        note 'using Build.PL';
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
        note "- $cmd";
        my $out = qx{$cmd 2>&1};
        if ( $? != 0 || $out =~ qr{^ERROR} )
        {    # Build do not set the status code correctly
            diag "failed to run $cmd\n", $out;
            return;
        }
    }

    return 1;
}
