
#!/bin/sh
#
# Copyright (c) 2025 OpenInfra Foundation Europe and others.
#

# Uncomment for debugging
# set -x

. "$SRCDIR/scripts/defines.sh"
. "$SCRIPTDIR/functions.sh"
mkdir -p "$TESTDIR" "$DBDIR1"

export PWDCHECK_MODULE_CONFIG_FILE="$TESTDIR/checker.conf"
start_slapd


echo "[TEST] Checker with configuration file..."
cat > "$TESTDIR/checker.conf" <<EOF
min_upper 2
min_points 1
max_consecutive_per_class 0
use_cracklib 0
EOF

attempt_password_change "abcdefghij"
expect_error_message "does not pass required number of strength checks for the required character sets (1 of 1)"
attempt_password_change "abcdEfgHij"
expect_success
echo "[PASS] Checker with configuration file"


shutdown_slapd
