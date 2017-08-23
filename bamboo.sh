#!/bin/sh

[ -e /usr/local/cpanel/3rdparty/perl/524/bin/perl ] && rpm -e --nodeps cpanel-perl-524 ||:
rpm -Uv --force rpms/cpanel-perl-526-5.26.0-1.debuginfo.cp1170.x86_64.rpm

