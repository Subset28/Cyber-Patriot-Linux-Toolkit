# shellcheck shell=bash
# Kernel network hardening via a sysctl.d drop-in (survives reboot).

mod_sysctl() {
    say "Kernel network hardening"
    local f=/etc/sysctl.d/99-cp-hardening.conf
    local content='net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.ip_forward = 0'
    if [ "$APPLY" -ne 1 ]; then
        echo "    [dry-run] write $f with:"
        printf '%s\n' "$content" | sed 's/^/        /'
    fi
    act "write $f" sh -c 'printf "%s\n" "$1" > "$2"' _ "$content" "$f"
    act "apply sysctl settings" sysctl --system --fallback sysctl -p "$f"
}
