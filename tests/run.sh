#!/bin/sh
#
# Copyright (c) 2025 OpenInfra Foundation Europe and others.
#

set -e

TOPDIR="$(cd "$(dirname "$0")/.." && pwd)"

cd $TOPDIR/openldap-src/tests
for script in $TOPDIR/tests/test-*.sh; do
    SCRIPTDIR=${TOPDIR}/tests DEFSDIR=${TOPDIR}/openldap-src/tests/scripts ./run $(basename "$script")
done
