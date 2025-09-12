#!/bin/sh
#
# Copyright (c) 2025 OpenInfra Foundation Europe and others.
#

set -x

echo "running defines.sh"
. $SRCDIR/scripts/defines.sh

mkdir -p $TESTDIR $DBDIR1

echo "Running slapadd to build slapd database..."
. $CONFFILTER $BACKEND <  $SCRIPTDIR/slapd.conf > $CONF1
$SLAPADD -f $CONF1 -l $SCRIPTDIR/test.ldif
RC=$?
if test $RC != 0 ; then
    echo "slapadd failed ($RC)!"
    exit $RC
fi

echo "Starting slapd on TCP/IP port $PORT1..."
$SLAPD -f $CONF1 -h $URI1 -d $LVL > $LOG1 2>&1 &
PID=$!
if test $WAIT != 0 ; then
    echo PID $PID
    read foo
fi
KILLPIDS="$PID"

sleep 1


echo "Testing changing password to a bad one"
$LDAPPASSWD -H $URI1 \
        -D "uid=user,ou=people,dc=example,dc=com" \
        -w secret \
        -s newsecret
RC=$?
##sleep 999999
if test $RC = 0 ; then
    echo "ldappasswd succeeded with a bad password ($RC)!"
fi
if test $RC != 53 ; then
    echo "ldappasswd returned $RC, not 53 as expected!"
    test $KILLSERVERS != no && kill -HUP $KILLPIDS
    exit 1
fi

test $KILLSERVERS != no && kill -HUP $KILLPIDS

echo ">>>>> Test succeeded"
test $KILLSERVERS != no && wait

exit 0
