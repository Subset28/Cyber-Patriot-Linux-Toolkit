# shellcheck shell=bash
# Audit logging (auditd) with rules for account, sudo, and SSH config changes.
# Matches the Windows audit policy step.

mod_logging() {
    say "Audit logging"
    act "install auditd" apt-get install -y auditd audispd-plugins --fallback apt-get install -y auditd
    act "turn on auditd at boot and start it" systemctl enable --now auditd --fallback service auditd start

    local rules=/etc/audit/rules.d/cp-toolkit.rules
    local content='-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /etc/ssh/sshd_config -p wa -k sshd
-w /etc/ssh/sshd_config.d/ -p wa -k sshd'
    act "write audit rules to $rules" sh -c 'mkdir -p /etc/audit/rules.d && printf "%s\n" "$1" > "$2"' _ "$content" "$rules"
    act "load audit rules" augenrules --load --fallback service auditd restart
}
