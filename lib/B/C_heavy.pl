package B::C;
use strict;

BEGIN {
    require B::C::Flags;
    *Config = \%B::C::Flags::Config;
}

use B::C::File qw( init2 init0 init decl free
  heksect binopsect condopsect copsect padopsect listopsect logopsect
  opsect pmopsect pvopsect svopsect unopsect svsect xpvsect xpvavsect xpvhvsect xpvcvsect xpvivsect xpvuvsect
  xpvnvsect xpvmgsect xpvlvsect xrvsect xpvbmsect xpviosect padlistsect loopsect sharedhe
);

use B::C::Packages qw/is_package_used mark_package_unused mark_package_used mark_package_removed get_all_packages_used/;

1;
