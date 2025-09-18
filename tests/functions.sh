#
# Copyright (c) 2025 OpenInfra Foundation Europe and others.
#

USERDN="uid=user,ou=people,dc=example,dc=com"

# Configure and start slapd server.
start_slapd() {
    echo "[INFO] Running slapadd to build slapd database..."
    . "$CONFFILTER" "$BACKEND" < "$SCRIPTDIR/slapd.conf" > "$CONF1"
    $SLAPADD -f "$CONF1" -l "$SCRIPTDIR/database.ldif"
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "[ERROR] slapadd failed ($rc)!" >&2
        exit $rc
    fi

    echo "[INFO] Starting slapd on $URI1..."
    $SLAPD -f "$CONF1" -h "$URI1" -d "$LVL" > "$LOG1" 2>&1 &
    PID=$!
    if [ "$WAIT" != "0" ]; then
        echo "PID $PID"
        read -r _
    fi
    KILLPIDS="$PID"

    sleep 1
}

# Shutdown slapd server.
shutdown_slapd() {
    echo "[INFO] Killing slapd..."
    [ "$KILLSERVERS" != "no" ] && kill -HUP "$KILLPIDS"
    [ "$KILLSERVERS" != "no" ] && wait
    exit 0
}

# Set checker config from STDIN.
set_pwd_check_module_arg() {
    local arg b64arg
    arg=$(cat)
    b64arg=$(echo -n "$arg" | base64 -w0)
    $LDAPMODIFY -v -D "$MANAGERDN" -H "$URI1" -w "$PASSWD" >/dev/null 2>&1 <<EOF
dn: cn=default,ou=policies,dc=example,dc=com
changetype: modify
replace: pwdCheckModuleArg
pwdCheckModuleArg:: $b64arg
EOF
}

# Attempt password change, returns exit code.
attempt_password_change() {
    local newpw="$1"
    echo "[INFO] Attempting password change to '$newpw'..."
    $LDAPPASSWD -H "$URI1" \
        -D "$USERDN" \
        -w "secret" \
        -s "$newpw" > "$TESTOUT"
    return $?
}

# Check for expected error message in TESTOUT.
expect_error_message() {
    local expected_msg="$1"
    if [ ! -s "$TESTOUT" ]; then
        echo "[ERROR] Output was empty, expected error message: '$expected_msg'" >&2
    [ "$KILLSERVERS" != "no" ] && kill -HUP "$KILLPIDS"
        exit 1
    fi
    if ! grep -q "$expected_msg" "$TESTOUT" ; then
        echo "[ERROR] Output did not contain expected error message: '$expected_msg'" >&2
        echo "Actual output:" >&2
        cat "$TESTOUT" >&2
    [ "$KILLSERVERS" != "no" ] && kill -HUP "$KILLPIDS"
        exit 1
    fi
}

# Check that TESTOUT is empty (no error message in log).
expect_no_message() {
    if [ -s "$TESTOUT" ]; then
        echo "[ERROR] Output was not empty as expected" >&2
        echo "Actual output:" >&2
        cat "$TESTOUT" >&2
    [ "$KILLSERVERS" != "no" ] && kill -HUP "$KILLPIDS"
        exit 1
    fi
}

# Check that previous command exited with expected status.
expect_status() {
    local expected_status="$1"
    local actual_status
    actual_status=$?
    if [ "$actual_status" -ne "$expected_status" ]; then
        echo "[ERROR] Exit status $actual_status, expected $expected_status" >&2
        echo "Actual output:" >&2
        cat "$TESTOUT" >&2
       [ "$KILLSERVERS" != "no" ] && kill -HUP "$KILLPIDS"
        exit 1
    fi
}

# Reset password back to original.
reset_password() {
    $LDAPMODIFY -v -D "$MANAGERDN" -H "$URI1" -w "$PASSWD" >/dev/null 2>&1 <<EOF
dn: $USERDN
changetype: modify
replace: userPassword
userPassword: secret
EOF
    local rc=$?
    if [ $rc -ne 0 ]; then
        echo "[ERROR] Failed to reset password!" >&2
    [ "$KILLSERVERS" != "no" ] && kill -HUP "$KILLPIDS"
        exit $rc
    fi
}

# Attempt password change using LDAPMODIFY, returns exit code.
attempt_password_change_with_modify() {
    local newpw="$1"
    local modify_op=$(cat <<EOF
dn: $USERDN
changetype: modify
replace: userPassword
userPassword: $newpw
EOF
)
    echo "[INFO] Attempting password change to '$newpw'..."
    echo "$modify_op"
    echo "$modify_op" | $LDAPMODIFY -v -D "$USERDN" -H "$URI1" -w "secret" >/dev/null 2>&1 > "$TESTOUT"
    echo "[INFO] LDAPMODIFY exit code: $?"
    return $?
}
