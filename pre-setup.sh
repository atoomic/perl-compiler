#!/bin/sh

echo "Removing perl524 / perl526 & installing perl528"
[ -e /usr/local/cpanel/3rdparty/perl/524/bin/perl ] && rpm -e --nodeps cpanel-perl-524 ||:
[ -e /usr/local/cpanel/3rdparty/perl/526/bin/perl ] && rpm -e --nodeps cpanel-perl-526 ||:

rpm -Uv --force rpms/cpanel-perl-528-5.28.0-0.cp1178.x86_64.rpm

echo "Setting prove for 528 - can also adjust symlinks"
[ -L /usr/local/cpanel/3rdparty/bin/prove ] && rm -f /usr/local/cpanel/3rdparty/bin/prove
ln -s /usr/local/cpanel/3rdparty/perl/528/bin/prove /usr/local/cpanel/3rdparty/bin/prove

# we now whave some custom RPMs available install and use them if possible
SRC="https://vmware-manager.dev.cpanel.net/RPM/11.78/centos/7/x86_64"
rpm -Uv \
    $SRC/cpanel-perl-528-DBI-1.641-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-DBD-SQLite-1.58-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-DBD-Pg-3.7.4-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-DBD-mysql-4.046_01-1.cp1178.x86_64.rpm

echo "Installing Test2 & modules used for testing"

rpm -Uv --force \
    $SRC/cpanel-perl-528-Class-XSAccessor-1.19-2.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Module-Pluggable-5.2-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Scope-Guard-0.21-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Sub-Info-0.002-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Term-Table-0.012-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Importer-0.025-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Moo-2.003004-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Ref-Util-XS-0.117-2.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Test-Simple-1.302140-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Test2-Suite-0.000115-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Module-Build-0.4224-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-App-cpanminus-1.7044-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Devel-GlobalDestruction-0.14-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Class-Method-Modifiers-2.12-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Role-Tiny-2.000006-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Sub-Quote-2.005001-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Module-Runtime-0.016-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Sub-Exporter-Progressive-0.001013-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-EV-4.22-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-common-sense-3.74-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-XML-Parser-2.44-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-libwww-perl-6.35-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Encode-Locale-1.05-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-File-Listing-6.04-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-HTML-Parser-3.72-2.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-LWP-MediaTypes-6.02-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Try-Tiny-0.30-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-URI-1.74-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-WWW-RobotRules-6.02-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-HTTP-Cookies-6.04-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-HTTP-Daemon-6.01-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-HTTP-Date-6.02-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-HTTP-Negotiate-6.01-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Net-HTTP-6.18-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-HTML-Tagset-3.20-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-HTTP-Message-6.18-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-IO-HTML-1.001-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-TAP-Formatter-JUnit-0.11-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-File-Slurp-9999.25-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Moose-2.2011-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-MooseX-NonMoose-0.26-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-XML-Generator-1.04-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Class-Load-0.25-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Class-Load-XS-0.10-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Data-OptList-0.110-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Devel-OverloadInfo-0.005-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Devel-StackTrace-2.03-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Dist-CheckConflicts-0.11-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Eval-Closure-0.14-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-MRO-Compat-0.13-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Module-Runtime-Conflicts-0.003-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Package-DeprecationManager-0.17-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Package-Stash-0.37-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Package-Stash-XS-0.28-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Params-Util-1.07-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Sub-Exporter-0.987-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Sub-Identify-0.14-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Sub-Name-0.21-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-List-MoreUtils-0.428-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Test-Fatal-0.014-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Module-Implementation-0.09-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Sub-Install-0.928-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Exporter-Tiny-1.002001-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-List-MoreUtils-XS-0.428-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Test-Trap-v0.3.3-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Data-Dump-1.23-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Test2-Tools-Explain-0.02-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Test-Deep-1.128-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Test2-Plugin-NoWarnings-0.06-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-B-Flags-0.17-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Capture-Tiny-0.48-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Template-Toolkit-2.27-6.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-AppConfig-1.71-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Class-Accessor-0.51-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-IO-stringy-2.111-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-IO-Socket-INET6-2.72-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-IO-Socket-SSL-2.060-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Net-SSLeay-1.85-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Socket6-0.28-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-JSON-XS-3.04-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Types-Serialiser-1.0-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Net-DNS-1.17-4.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Digest-HMAC-1.03-1.cp1178.noarch.rpm \
    $SRC/cpanel-perl-528-Net-LibIDN-0.12-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-XString-0.001-1.cp1178.x86_64.rpm \
    $SRC/cpanel-perl-528-Sub-Quote-2.006003-2.cp1178.noarch.rpm

cd src
/usr/local/cpanel/3rdparty/bin/perl528 install-perl-modules.pl

/usr/local/cpanel/3rdparty/bin/perl528 -MTAP::Formatter::JUnit -E "say q[perl installed with TAP::Formatter::JUnit];"

#/usr/local/cpanel/3rdparty/bin/perl528 -MTAP::Formatter::JUnit -E "say q[can find TAP::Formatter::JUnit]; use Test::More; note explain \%INC"

echo "Using prove: "
ls -l /usr/local/cpanel/3rdparty/bin/prove
