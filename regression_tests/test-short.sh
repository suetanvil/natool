#!/bin/sh

# This runs test.sh with a smaller set of input data.  This is less
# useful but slightly faster.  (This used to be *much* faster before I
# fixed some O(n^2) algorithms.)

set -e

cd `dirname $0`

sh test.sh ../orig-short/




