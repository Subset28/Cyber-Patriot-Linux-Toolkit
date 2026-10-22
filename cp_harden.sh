#!/bin/bash
# CyberPatriot Linux toolkit (Mint, Ubuntu, Debian). Dry run by default.
# Usage: sudo bash cp_harden.sh [--apply] [--only a,b] [--skip a,b] [--list]
#   --apply   make changes (otherwise only prints what would happen)
#   --only    run just these modules
#   --skip    run everything except these
#   --list    print module names and exit
#   --show    print the users, admins, and services read from the README, then exit
# Logs, transcript, backups, and summary: /root/cp-reports/run-<time>/
# To halt before the next module: sudo touch /root/cp-reports/STOP
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"
. "$DIR/config.env"

# Grouped in the order to work through: accounts, system settings, services and packages, updates and malware, files, review, final check.
MODULES="users auth groups guest ssh sysctl firewall perms logging services packages updates malware userfiles media removepaths review forensics audit"

APPLY=0
SHOW=0
ONLY=""
SKIP=""
while [ $# -gt 0 ]; do
    case "$1" in
        --apply) APPLY=1 ;;
        --show)  SHOW=1 ;;
        --only)  ONLY=${2:-}; shift ;;
        --skip)  SKIP=${2:-}; shift ;;
        --list)  echo "$MODULES" | tr ' ' '\n'; exit 0 ;;
        *) echo "unknown argument: $1"; exit 1 ;;
    esac
    shift
done
ONLY=${ONLY//,/ }
SKIP=${SKIP//,/ }

want() {
    local m=$1
    if [ -n "$ONLY" ] && ! inlist "$ONLY" "$m"; then return 1; fi
    if inlist "$SKIP" "$m"; then return 1; fi
    return 0
}

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo"; exit 1; }
command -v apt-get >/dev/null || { echo "This toolkit needs an apt-based system"; exit 1; }

RUN_DIR="$REPORT_DIR/run-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RUN_DIR"
exec > >(tee -a "$RUN_DIR/transcript.txt") 2>&1

detect_env
echo "OS: $OS_NAME"
echo "Mode: $([ "$APPLY" -eq 1 ] && echo APPLY || echo DRY-RUN)"
log INFO "run start: mode=$([ "$APPLY" -eq 1 ] && echo APPLY || echo DRY-RUN) user=${SUDO_USER:-root} os=$OS_NAME ssh_unit=${SSH_UNIT:-none} display_manager=${DM:-unknown}"

: "${ADMINS:=}"
: "${USERS:=}"
: "${SERVICES:=}"
if [ -z "$ADMINS" ] || [ -z "$USERS" ] || [ -z "$SERVICES" ]; then
    README=$(find_readme)
    [ -n "$README" ] || README=$(ask "README path: ")
    [ -f "$README" ] || { echo "README not found: $README"; exit 1; }
    [ -n "$ADMINS" ]   || ADMINS=$(parse_section '^Authorized Administrators:?[ ]*$' '^Authorized Users:?[ ]*$')
    [ -n "$USERS" ]    || USERS=$(parse_section '^Authorized Users:?[ ]*$' '^(Competition Guidelines|Critical Services)')
    [ -n "$SERVICES" ] || SERVICES=$(parse_section '^Critical Services:?[ ]*$' '^Authorized Administrators')
    [ -n "$SERVICES" ] || SERVICES=$(parse_services)
    [ -n "$SERVICES" ] || show_service_lines
    echo "Parsed from $README"
fi
[ -n "$ADMINS" ] || { echo "No administrators found. Set ADMINS in config.env."; exit 1; }
echo "    admins:   $ADMINS"
echo "    users:    $USERS"
echo "    services: $SERVICES"
if [ "$SHOW" -eq 1 ]; then
    echo "Show only. Nothing was changed."
    exit 0
fi

: "${NEW_ADMINS:=}"
if ! grep -q '^[^#]*NEW_ADMINS=' "$DIR/config.env"; then
    # Names must start with a letter, so a stray number is not taken as an account name.
    while :; do
        NEW_ADMINS=$(ask "New admin accounts to create, space-separated (press Enter for none): ")
        bad=""
        for n in $NEW_ADMINS; do [[ $n =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || bad="$bad $n"; done
        [ -z "$bad" ] && break
        echo "    Not a valid account name:$bad. Use lowercase letters and numbers, starting with a letter."
    done
fi

save_backups

if [ "$APPLY" -eq 1 ]; then
    present=0
    for u in $ADMINS; do id "$u" >/dev/null 2>&1 && present=$((present + 1)); done
    if [ "$present" -eq 0 ]; then
        echo "SAFETY: none of the listed admins exist on this machine. Refusing to apply."
        log FAILED "safety: no listed admin accounts exist"
        write_summary
        exit 1
    fi
    if [ -n "${SSH_CONNECTION:-}" ] && [ -z "$SSH_UNIT" ] && want firewall; then
        echo "SAFETY: this is an SSH session but no SSH service was found. Enabling ufw could drop it. Refusing to apply."
        log FAILED "safety: SSH session without an SSH service"
        write_summary
        exit 1
    fi
fi

for m in $MODULES; do
    want "$m" || continue
    if [ -e "$REPORT_DIR/STOP" ]; then
        echo "STOP file found in $REPORT_DIR. Halting before $m."
        log STOP "halted before $m"
        break
    fi
    . "$DIR/modules/$m.sh"
    if ! ( "mod_$m" ); then
        echo "[*] module $m failed (see run.log). Continuing."
        log ERROR "module $m failed"
        record FAILED "module $m"
    fi
done

write_summary
[ "$APPLY" -eq 1 ] || echo "Dry run only. Re-run with --apply to make changes."
