#!/bin/sh

set -e

for d in "op" "base"; do
    pushd $d
    echo "* $d"
    for t in *.t; do
        echo - updating: $t
        unlink $t
        ln -s ../template.pl $t
    done
    popd
done
