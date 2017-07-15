package B::C::Config;

use strict;

use B::C::Flags ();
use B::C::Debug ();

use Exporter ();
our @ISA = qw(Exporter);

# alias
*debug           = \&B::C::Debug::debug;
*debug_all       = \&B::C::Debug::enable_all;
*verbose         = \&B::C::Debug::verbose;
*display_message = \&B::C::Debug::display_message;

*WARN  = \&B::C::Debug::WARN;
*INFO  = \&B::C::Debug::INFO;
*FATAL = \&B::C::Debug::FATAL;

# usually 0x400000, but can be as low as 0x10000
# http://docs.embarcadero.com/products/rad_studio/delphiAndcpp2009/HelpUpdate2/EN/html/devcommon/compdirsimagebaseaddress_xml.html
# called mapped_base on linux (usually 0xa38000)
sub LOWEST_IMAGEBASE() { 0x10000 }

sub _autoload_map {

    my $map = {};

    # debugging variables
    $map->{'DEBUGGING'} = ( $B::C::Flags::Config{ccflags} =~ m/-DDEBUGGING/ );

    return $map;
}

my $_autoload;

BEGIN {
    $_autoload = _autoload_map();
    our @EXPORT_OK = sort keys %$_autoload;
    push @EXPORT_OK, qw/debug debug_all display_message verbose WARN INFO FATAL LOWEST_IMAGEBASE/;
    our @EXPORT = @EXPORT_OK;
}

1;
