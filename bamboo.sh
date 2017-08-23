#!/bin/sh

echo "Removing perl524 & installing perl526"
[ -e /usr/local/cpanel/3rdparty/perl/524/bin/perl ] && rpm -e --nodeps cpanel-perl-524 ||:
rpm -Uv --force rpms/cpanel-perl-526-5.26.0-1.debuginfo.cp1170.x86_64.rpm

echo "Setting prove for 526 - can also adjust symlinks"
[ -L /usr/local/cpanel/3rdparty/bin/prove ] && rm -f /usr/local/cpanel/3rdparty/bin/prove
ln -s /usr/local/cpanel/3rdparty/perl/526/bin/prove /usr/local/cpanel/3rdparty/bin/prove
