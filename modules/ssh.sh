# shellcheck shell=bash
# SSH hardening. Never stops or disables the service. Restarts only after sshd -t passes.

mod_ssh() {
    say "SSH (critical service: hardened, never stopped)"
    if [ -z "$SSH_UNIT" ]; then
        echo "    no SSH service found. Check the README's critical services."
        log WARN "no SSH service found"
        return 0
    fi
    local cfg=/etc/ssh/sshd_config
    setline "$cfg" PermitRootLogin "PermitRootLogin no"
    setline "$cfg" PermitEmptyPasswords "PermitEmptyPasswords no"
    setline "$cfg" X11Forwarding "X11Forwarding no"
    for f in /etc/ssh/sshd_config.d/*.conf; do
        [ -f "$f" ] && grep -qi '^[[:space:]]*PermitRootLogin' "$f" && setline "$f" PermitRootLogin "PermitRootLogin no"
    done
    # sshd -t refuses to run without its privilege-separation directory (it is made when sshd starts).
    [ -d /run/sshd ] || act "create /run/sshd (needed by sshd -t)" mkdir -p -m 0755 /run/sshd
    if act "validate sshd configuration" sshd -t; then
        act "restart $SSH_UNIT" systemctl restart "$SSH_UNIT" --fallback service "$SSH_UNIT" restart
    else
        echo "    sshd -t failed. Restoring the backed-up configuration."
        act "restore sshd_config from backup" cp -a "$RUN_DIR/backup/sshd_config" "$cfg"
        [ -d "$RUN_DIR/backup/sshd_config.d" ] && act "restore sshd_config.d from backup" cp -a "$RUN_DIR/backup/sshd_config.d/." /etc/ssh/sshd_config.d/
    fi
}
