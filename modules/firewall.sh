# shellcheck shell=bash
# UFW. Allows SSH (if installed) and any ports in ALLOW_TCP_PORTS, then enables.
# Enabling is skipped if the SSH allow rule failed, so the session is not cut off.

mod_firewall() {
    say "Firewall"
    act "install ufw" apt-get install -y ufw
    act "ufw default deny incoming" ufw default deny incoming
    act "ufw default allow outgoing" ufw default allow outgoing

    local ssh_ok=1
    if [ -n "$SSH_UNIT" ]; then
        act "allow SSH 22/tcp" ufw allow 22/tcp --fallback iptables -A INPUT -p tcp --dport 22 -j ACCEPT || ssh_ok=0
    fi
    for p in $ALLOW_TCP_PORTS; do
        [ "$p" = 22 ] && [ -n "$SSH_UNIT" ] && continue   # already allowed above
        act "allow $p/tcp" ufw allow "$p/tcp" --fallback iptables -A INPUT -p tcp --dport "$p" -j ACCEPT
    done
    act "ufw logging on" ufw logging on

    if [ "$ssh_ok" -eq 1 ]; then
        act "enable ufw" ufw --force enable --fallback systemctl enable --now ufw
    else
        echo "    not enabling ufw: the SSH allow rule failed"
        log ERROR "ufw not enabled: SSH allow rule failed"
        record FAILED "enable ufw (blocked: SSH rule failed)"
    fi
}
