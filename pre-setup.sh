#!/bin/sh

echo "Removing perl524 / perl526 & installing perl528"
[ -e /usr/local/cpanel/3rdparty/perl/524/bin/perl ] && rpm -e --nodeps cpanel-perl-524 ||:
[ -e /usr/local/cpanel/3rdparty/perl/526/bin/perl ] && rpm -e --nodeps cpanel-perl-526 ||:
rpm -Uv --force rpms/cpanel-perl-528-5.28.0-0.cp1170.x86_64.rpm

echo "Setting prove for 528 - can also adjust symlinks"
[ -L /usr/local/cpanel/3rdparty/bin/prove ] && rm -f /usr/local/cpanel/3rdparty/bin/prove
ln -s /usr/local/cpanel/3rdparty/perl/528/bin/prove /usr/local/cpanel/3rdparty/bin/prove

cd src
/usr/local/cpanel/3rdparty/bin/perl528 install-perl-modules.pl

/usr/local/cpanel/3rdparty/bin/perl528 -MTAP::Formatter::JUnit -E "say q[perl installed with TAP::Formatter::JUnit];"

#/usr/local/cpanel/3rdparty/bin/perl528 -MTAP::Formatter::JUnit -E "say q[can find TAP::Formatter::JUnit]; use Test::More; note explain \%INC"

ls -l /usr/local/cpanel/3rdparty/bin/prove
