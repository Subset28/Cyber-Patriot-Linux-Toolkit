# shellcheck shell=bash
# Password policy and lockout. Forced resets are handled in users.sh.

mod_auth() {
    say "Password aging and complexity"
    setline /etc/login.defs PASS_MAX_DAYS "PASS_MAX_DAYS   $PASS_MAX_DAYS"
    setline /etc/login.defs PASS_MIN_DAYS "PASS_MIN_DAYS   $PASS_MIN_DAYS"
    setline /etc/login.defs PASS_WARN_AGE "PASS_WARN_AGE   $PASS_WARN_AGE"
    act "install libpam-pwquality" apt-get install -y libpam-pwquality
    setline /etc/security/pwquality.conf minlen "minlen = $PASS_MIN_LEN"
    setline /etc/security/pwquality.conf dcredit "dcredit = -1"
    setline /etc/security/pwquality.conf ucredit "ucredit = -1"
    setline /etc/security/pwquality.conf lcredit "lcredit = -1"
    setline /etc/security/pwquality.conf ocredit "ocredit = -1"

    say "Account lockout"
    setline /etc/security/faillock.conf deny "deny = $FAILLOCK_DENY"
    setline /etc/security/faillock.conf unlock_time "unlock_time = $FAILLOCK_UNLOCK"
    grep -q pam_faillock /etc/pam.d/common-auth 2>/dev/null || echo "    pam_faillock is not in /etc/pam.d/common-auth. Add it by hand; a broken PAM file locks everyone out."
    if grep -q 'remember=' /etc/pam.d/common-password 2>/dev/null; then
        echo "    password history already set in common-password"
    elif grep -qE '^password.*pam_unix\.so' /etc/pam.d/common-password 2>/dev/null; then
        # Only the pam_unix line is changed. A copy is kept in the run folder in case it needs to go back.
        [ -n "${RUN_DIR:-}" ] && [ -f /etc/pam.d/common-password ] && cp -a /etc/pam.d/common-password "$RUN_DIR/backup/" 2>/dev/null
        act "set password history to 5 (remember=5) in common-password" \
            sed -i -E '/^password.*pam_unix\.so/ s/$/ remember=5/' /etc/pam.d/common-password
    else
        echo "    password history (remember=) could not be set: no pam_unix line in common-password. Add it by hand."
    fi
}
