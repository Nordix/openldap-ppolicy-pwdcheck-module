#!/bin/sh
#
# Copyright (c) 2025 OpenInfra Foundation Europe and others.
#

# Uncomment for debugging
# set -x


. "$SRCDIR/scripts/defines.sh"
. "$SCRIPTDIR/functions.sh"
mkdir -p "$TESTDIR" "$DBDIR1"


start_slapd


echo "[TEST] Default configuration..."
attempt_password_change "F#k2r!m.9"
expect_no_message
reset_password
attempt_password_change "simple"
expect_error_message "Too many consecutive characters in the same character class"
attempt_password_change "SimPle"
expect_error_message "does not pass required number of strength checks for the required character sets (2 of 3)"
attempt_password_change "SimPle!"
expect_no_message
reset_password
attempt_password_change "Simple1"
expect_no_message
echo "[PASS] Default configuration"

echo "[TEST] min_* as 1..."
set_pwd_check_module_arg <<EOF
min_upper 1
min_lower 1
min_digit 1
min_punct 1
min_points 3
max_consecutive_per_class 0
use_cracklib 0
EOF
reset_password
attempt_password_change "simple"
expect_error_message "does not pass required number of strength checks for the required character sets (1 of 3)"
reset_password
attempt_password_change "SimPle"
expect_error_message "does not pass required number of strength checks for the required character sets (2 of 3)"
reset_password
attempt_password_change "SimPle!"
expect_error_message "does not pass required number of strength checks for the required character sets (3 of 3)"
reset_password
attempt_password_change "Simple1!"
expect_no_message
echo "[PASS] min_* as 1"

echo "[TEST] min_upper..."
set_pwd_check_module_arg <<EOF
min_upper 2
min_points 1
max_consecutive_per_class 0
use_cracklib 0
EOF
reset_password
attempt_password_change "abcdefghij"
expect_error_message "does not pass required number of strength checks for the required character sets (1 of 1)"
attempt_password_change "abcdEfgHij"
expect_no_message
echo "[PASS] min_upper"

echo "[TEST] min_lower..."
set_pwd_check_module_arg <<EOF
min_lower 2
min_points 1
max_consecutive_per_class 0
use_cracklib 0
EOF
reset_password
attempt_password_change "ABCDEFGHIJ"
expect_error_message "does not pass required number of strength checks for the required character sets (1 of 1)"
attempt_password_change "ABCDfGHij"
expect_no_message
echo "[PASS] min_lower"

echo "[TEST] min_digit..."
set_pwd_check_module_arg <<EOF
min_digit 2
min_points 1
max_consecutive_per_class 0
use_cracklib 0
EOF
reset_password
attempt_password_change "abcdefghij"
expect_error_message "does not pass required number of strength checks for the required character sets (1 of 1)"
attempt_password_change "abcd3fgh1j"
expect_no_message
echo "[PASS] min_digit"

echo "[TEST] min_punct..."
set_pwd_check_module_arg <<EOF
min_punct 2
min_points 1
max_consecutive_per_class 0
use_cracklib 0
EOF
reset_password
attempt_password_change "abcdefghij"
expect_error_message "does not pass required number of strength checks for the required character sets (1 of 1)"
attempt_password_change "abcd!fgh/j"
expect_no_message
echo "[PASS] min_punct"

# NOTE: max_consecutive_per_class counts wrong in current implementation, so we need to set 3 to allow 2 consecutive chars.
echo "[TEST] max_consecutive_per_class..."
set_pwd_check_module_arg <<EOF
min_points 1
max_consecutive_per_class 5
use_cracklib 0
EOF
reset_password
attempt_password_change "abcdeABCDE12345"
expect_error_message "Too many consecutive characters in the same character class"
attempt_password_change "abcdABCD1234"
expect_no_message
echo "[PASS] max_consecutive_per_class"

echo "[TEST] use_cracklib..."
set_pwd_check_module_arg <<EOF
use_cracklib 1
min_points 1
max_consecutive_per_class 0
EOF
reset_password
attempt_password_change "dictionary"
expect_error_message "because it is based on a dictionary word"
reset_password
attempt_password_change "abcdefghij"
expect_error_message "because it is too simplistic/systematic"
echo "[PASS] use_cracklib"

echo "[TEST] contains_username..."
set_pwd_check_module_arg <<EOF
contains_username TRUE
min_points 1
max_consecutive_per_class 0
use_cracklib FALSE
EOF
reset_password
attempt_password_change "username"
expect_error_message "because it contains the username"
attempt_password_change "Username"
expect_error_message "because it contains the username"
attempt_password_change "Foousername"
expect_error_message "because it contains the username"
attempt_password_change "FooBaruser"
expect_error_message "because it contains the username"
echo "[PASS] contains_username"


shutdown_slapd
