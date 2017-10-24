#!./perl

BEGIN {
    chdir 't' if -d 't';
    require "./test.pl";

    # use absolute path
    my $pwd = qx{pwd};
    chomp $pwd;

    set_up_inc("$pwd/extra");
}

# lazy load module at runtime which execute a BEGIN block

plan(3);

ok !$INC{'BeginLazyLoad.pm'}, 'module is not loaded';
eval q{require BeginLazyLoad} or die "Fail to load BeginLazyLoad.pm: $!";
ok $INC{'BeginLazyLoad.pm'}, 'module is lazy loaded';

is $BeginLazyLoad::loaded, 42, "variable is set from BEGIN block while lazy loading it";
