#!/bin/sh

SRC="https://vmware-manager.dev.cpanel.net/RPM/11.86/centos/7/x86_64"

echo "Removing perl 524, 526, 528& installing perl530"
for V in "524" "526" "528"; do
    [ -e /usr/local/cpanel/3rdparty/perl/$V/bin/perl ] && rpm -e --nodeps cpanel-perl-$V ||:
done

rpm -Uv --force $SRC/cpanel-perl-530-5.30.0-1.cp1186.x86_64.rpm ||:

echo "Setting prove for 530 - can also adjust symlinks"
[ -L /usr/local/cpanel/3rdparty/bin/prove ] && rm -f /usr/local/cpanel/3rdparty/bin/prove
ln -s /usr/local/cpanel/3rdparty/perl/530/bin/prove /usr/local/cpanel/3rdparty/bin/prove

# we now whave some custom RPMs available install and use them if possible
rpm -Uv \
    $SRC/cpanel-perl-530-DBI-1.641-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-DBD-SQLite-1.58-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-DBD-Pg-3.7.4-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-DBD-mysql-4.046_01-1.cp1186.x86_64.rpm

echo "Installing Test2 & modules used for testing"

rpm -Uv --force \
    $SRC/cpanel-perl-530-Class-XSAccessor-1.19-2.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Module-Pluggable-5.2-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Scope-Guard-0.21-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Sub-Info-0.002-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Term-Table-0.012-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Importer-0.025-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Moo-2.003004-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Ref-Util-XS-0.117-2.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Test-Simple-1.302140-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Test2-Suite-0.000115-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Module-Build-0.4224-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-App-cpanminus-1.7044-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Devel-GlobalDestruction-0.14-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Class-Method-Modifiers-2.12-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Role-Tiny-2.000006-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Sub-Quote-2.005001-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Module-Runtime-0.016-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Sub-Exporter-Progressive-0.001013-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-EV-4.22-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-common-sense-3.74-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-XML-Parser-2.44-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-libwww-perl-6.35-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Encode-Locale-1.05-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-File-Listing-6.04-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-HTML-Parser-3.72-2.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-LWP-MediaTypes-6.02-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Try-Tiny-0.30-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-URI-1.74-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-WWW-RobotRules-6.02-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-HTTP-Cookies-6.04-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-HTTP-Daemon-6.01-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-HTTP-Date-6.02-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-HTTP-Negotiate-6.01-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Net-HTTP-6.18-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-HTML-Tagset-3.20-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-HTTP-Message-6.18-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-IO-HTML-1.001-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-TAP-Formatter-JUnit-0.11-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-File-Slurp-9999.25-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Moose-2.2011-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-MooseX-NonMoose-0.26-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-XML-Generator-1.04-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Class-Load-0.25-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Class-Load-XS-0.10-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Data-OptList-0.110-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Devel-OverloadInfo-0.005-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Devel-StackTrace-2.03-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Dist-CheckConflicts-0.11-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Eval-Closure-0.14-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-MRO-Compat-0.13-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Module-Runtime-Conflicts-0.003-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Package-DeprecationManager-0.17-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Package-Stash-0.37-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Package-Stash-XS-0.28-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Params-Util-1.07-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Sub-Exporter-0.987-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Sub-Identify-0.14-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Sub-Name-0.21-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-List-MoreUtils-0.428-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Test-Fatal-0.014-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Module-Implementation-0.09-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Sub-Install-0.928-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Exporter-Tiny-1.002001-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-List-MoreUtils-XS-0.428-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Test-Trap-v0.3.3-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Data-Dump-1.23-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Test2-Tools-Explain-0.02-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Test-Deep-1.128-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Test2-Plugin-NoWarnings-0.06-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-B-Flags-0.17-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Capture-Tiny-0.48-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Template-Toolkit-2.27-6.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-AppConfig-1.71-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Class-Accessor-0.51-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-IO-stringy-2.111-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-IO-Socket-INET6-2.72-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-IO-Socket-SSL-2.060-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Net-SSLeay-1.85-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Socket6-0.28-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-JSON-XS-3.04-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Types-Serialiser-1.0-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Net-DNS-1.17-4.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Digest-HMAC-1.03-1.cp1186.noarch.rpm \
    $SRC/cpanel-perl-530-Net-LibIDN-0.12-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-XString-0.001-1.cp1186.x86_64.rpm \
    $SRC/cpanel-perl-530-Sub-Quote-2.006003-2.cp1186.noarch.rpm

cd src
/usr/local/cpanel/3rdparty/bin/perl530 install-perl-modules.pl
/usr/local/cpanel/3rdparty/bin/perl530 -MTAP::Formatter::JUnit -E "say q[perl installed with TAP::Formatter::JUnit];"

echo "Using prove: "
ls -l /usr/local/cpanel/3rdparty/bin/prove
