# shellcheck shell=bash
# Critical services are reported and never touched. Prohibited services are listed, and you pick
# which to stop and disable. Services the README names as critical are never offered.

PROHIBITED_SERVICES="telnet.socket telnetd.socket vsftpd proftpd pure-ftpd tftpd-hpa tftpd rsh.socket rlogin.socket rexec.socket snmpd nfs-server rpcbind apache2 lighttpd nginx"

# Non-essential services that do not affect the VM: stopped and disabled automatically, unless the README names them.
SAFE_STOP_SERVICES="avahi-daemon cups cups-browsed bluetooth ModemManager whoopsie kerneloops speech-dispatcher colord geoclue apport switcheroo-control rtkit-daemon"

mod_services() {
    say "Critical services from the README"
    for s in $SERVICES; do
        if systemctl is-active --quiet "$s"; then
            echo "    active: $s"
        else
            echo "    NOT ACTIVE: $s (check before changing anything)"
        fi
    done

    say "Prohibited services (you pick which to stop and disable)"
    local svc
    local -a found=() picked=()
    for svc in $PROHIBITED_SERVICES; do
        if inlist " $SERVICES " "$svc" || inlist " $SERVICES " "${svc%.*}"; then
            echo "    kept (named as critical in the README): $svc"
            continue
        fi
        systemctl cat "$svc" >/dev/null 2>&1 || continue
        if systemctl is-active --quiet "$svc" || systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            found+=("$svc")
        fi
    done

    if [ "${#found[@]}" -eq 0 ]; then
        echo "    no prohibited services running or enabled"
        return 0
    fi
    echo "    ${#found[@]} prohibited service(s) running or enabled:"
    if [ "$APPLY" -ne 1 ]; then
        printf '    %s\n' "${found[@]}"
        echo "    [dry-run] in apply mode you pick which services to stop"
        return 0
    fi
    mapfile -t picked < <(pick_numbers "Stop which of these? (numbers separated by commas, or type none)" "${found[@]}")
    for svc in "${picked[@]}"; do
        [ -n "$svc" ] || continue
        act "stop and disable $svc" sh -c 'systemctl disable --now "$1"' _ "$svc" \
            --fallback sh -c 'systemctl stop "$1"; systemctl disable "$1"' _ "$svc"
    done
    echo "    services you did not pick are left running"
    stop_safe_services
}

# Stops and disables the non-essential services in SAFE_STOP_SERVICES that are running or enabled.
stop_safe_services() {
    say "Non-essential services (stopped and disabled automatically; README-named ones are kept)"
    local svc
    for svc in $SAFE_STOP_SERVICES; do
        if inlist " $SERVICES " "$svc" || inlist " $SERVICES " "${svc%.*}"; then
            echo "    kept (named in the README): $svc"
            continue
        fi
        systemctl cat "$svc" >/dev/null 2>&1 || continue
        if systemctl is-active --quiet "$svc" || systemctl is-enabled --quiet "$svc" 2>/dev/null; then
            act "stop and disable $svc" sh -c 'systemctl disable --now "$1"' _ "$svc" \
                --fallback sh -c 'systemctl stop "$1"; systemctl disable "$1"' _ "$svc"
        fi
    done
}
