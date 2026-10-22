# shellcheck shell=bash
# Critical services are reported and never touched. Prohibited services are stopped and disabled,
# unless the README names them as critical.

PROHIBITED_SERVICES="telnet.socket telnetd.socket vsftpd proftpd pure-ftpd tftpd-hpa tftpd rsh.socket rlogin.socket rexec.socket snmpd nfs-server rpcbind"

mod_services() {
    say "Critical services from the README"
    for s in $SERVICES; do
        if systemctl is-active --quiet "$s"; then
            echo "    active: $s"
        else
            echo "    NOT ACTIVE: $s (check before changing anything)"
        fi
    done

    say "Prohibited services"
    local svc
    for svc in $PROHIBITED_SERVICES; do
        if inlist " $SERVICES " "$svc" || inlist " $SERVICES " "${svc%.*}"; then
            echo "    kept (named as critical in the README): $svc"
            continue
        fi
        systemctl cat "$svc" >/dev/null 2>&1 || continue
        if systemctl is-active --quiet "$svc" || systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            echo "    found: $svc"
            act "stop and disable $svc" sh -c 'systemctl disable --now "$1"' _ "$svc" \
                --fallback sh -c 'systemctl stop "$1"; systemctl disable "$1"' _ "$svc"
        fi
    done
}
