#!/bin/sh

echo "Removing perl524 / perl526 & installing perl528"
[ -e /usr/local/cpanel/3rdparty/perl/524/bin/perl ] && rpm -e --nodeps cpanel-perl-524 ||:
[ -e /usr/local/cpanel/3rdparty/perl/526/bin/perl ] && rpm -e --nodeps cpanel-perl-526 ||:

rpm -Uv --force rpms/cpanel-perl-528-5.28.0-0.cp1178.x86_64.rpm

echo "Setting prove for 528 - can also adjust symlinks"
[ -L /usr/local/cpanel/3rdparty/bin/prove ] && rm -f /usr/local/cpanel/3rdparty/bin/prove
ln -s /usr/local/cpanel/3rdparty/perl/528/bin/prove /usr/local/cpanel/3rdparty/bin/prove

cd src
/usr/local/cpanel/3rdparty/bin/perl528 install-perl-modules.pl

/usr/local/cpanel/3rdparty/bin/perl528 -MTAP::Formatter::JUnit -E "say q[perl installed with TAP::Formatter::JUnit];"

# we now whave some custom RPMs available install and use them if possible
SRC="https://vmware-manager.dev.cpanel.net/RPM/11.78/centos/7/x86_64"
rpm -Uv \
    $SRC/cpanel-perl-528-DBI-1.641-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-DBD-SQLite-1.58-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-DBD-Pg-3.7.4-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-DBD-mysql-4.046_01-1.cp1178.x86_64.rpm

#/usr/local/cpanel/3rdparty/bin/perl528 -MTAP::Formatter::JUnit -E "say q[can find TAP::Formatter::JUnit]; use Test::More; note explain \%INC"

echo "Using prove: "
ls -l /usr/local/cpanel/3rdparty/bin/prove
