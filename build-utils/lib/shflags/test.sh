#!/bin/bsh
. ./shflags
DEFINE_string test "" "test" "t"
FLAGS "$@" || exit $?
echo ${FLAGS_test}
