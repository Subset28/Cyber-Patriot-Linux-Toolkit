#!/bin/bash
# CyberPatriot Linux toolkit (Mint, Ubuntu, Debian). Dry run by default.
# Usage: sudo bash cp_harden.sh [--apply] [--ask] [--no-pause] [--only a,b] [--skip a,b]
#                               [--list] [--show] [--results] [--undo]
#   --apply     make changes (otherwise only prints what would happen)
#   --ask       ask y/n before each step (Enter does not answer)
#   --no-pause  do not wait for Enter between steps
#   --only      run just these steps
#   --skip      run everything except these steps
#   --list      print step names in order and exit
#   --show      print the users, admins, and services read from the README, then exit
#   --results   print the last run's results and failed actions, then exit
#   --undo      put back the config files saved by the last run, then exit
# Logs, transcript, backups, and summary: /root/cp-reports/run-<time>/
# To halt before the next step: sudo touch /root/cp-reports/STOP
set -u

DIR=$(cd "$(dirname "$0")" && pwd)
. "$DIR/lib.sh"
. "$DIR/config.env"

# Forensics first, so the questions are read before anything changes.
MODULES="forensics users auth groups sudoers guest ssh sysctl firewall perms logging services packages updates malware userfiles media removepaths review audit"

# One line per step, shown in the "Run this step" question.
step_desc() {
    case "$1" in
        forensics)   echo "list the Forensics Question files on the Desktop. Answer them before any other step changes anything" ;;
        users)       echo "accounts and admins: remove accounts not on the README lists, fix admin rights, offer to create missing authorized accounts, set passwords, lock root" ;;
        auth)        echo "password aging, password quality, lockout, and password history" ;;
        groups)      echo "group membership from GroupMembers, and README groups that do not exist" ;;
        guest)       echo "turn off the guest login (LightDM)" ;;
        ssh)         echo "harden sshd: no root login, no empty passwords. SSH is never stopped" ;;
        sysctl)      echo "network hardening settings in /etc/sysctl.d" ;;
        firewall)    echo "enable UFW: deny inbound, allow SSH and ALLOW_TCP_PORTS" ;;
        perms)       echo "ownership and modes on the account and password files" ;;
        logging)     echo "install and turn on auditd, with rules for account, sudo, and SSH config changes" ;;
        services)    echo "check the README's critical services, then pick prohibited services to stop and disable" ;;
        packages)    echo "pick prohibited software to remove (protected packages are never offered)" ;;
        updates)     echo "package updates and automatic security updates" ;;
        malware)     echo "report only: planted programs, startup entries, and keys (nothing is removed)" ;;
        userfiles)   echo "pick scripts, executables, and hacking tools in user folders to remove" ;;
        media)       echo "pick media files outside work folders to delete" ;;
        removepaths) echo "pick folders in user home folders to delete" ;;
        review)      echo "pick loose files at the top of / and running programs to remove or stop. Listening ports are report only" ;;
        audit)       echo "final check: accounts, sudo, ports, cron, SUID files, and more (report only)" ;;
        *)           echo "$1" ;;
    esac
}

APPLY=0
SHOW=0
ASK=0
NOPAUSE=0
RESULTS=0
UNDO=0
ONLY=""
SKIP=""
while [ $# -gt 0 ]; do
    case "$1" in
        --apply)     APPLY=1 ;;
        --show)      SHOW=1 ;;
        --ask)       ASK=1 ;;
        --no-pause)  NOPAUSE=1 ;;
        --results)   RESULTS=1 ;;
        --undo)      UNDO=1 ;;
        --only)      ONLY=${2:-}; shift ;;
        --skip)      SKIP=${2:-}; shift ;;
        --list)      echo "$MODULES" | tr ' ' '\n'; exit 0 ;;
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

# Prints the results of the newest run: summary, and any failed actions.
show_last_results() {
    local last
    last=$(latest_run)
    [ -n "$last" ] || { echo "No previous run found in $REPORT_DIR."; return 1; }
    echo "Last run: $last"
    [ -f "$last/summary.json" ] && cat "$last/summary.json"
    if [ -f "$last/results.tsv" ] && awk -F'\t' '$1=="FAILED"{f=1} END{exit !f}' "$last/results.tsv"; then
        echo "Failed actions (check by hand):"
        awk -F'\t' '$1=="FAILED"{print "    " $2}' "$last/results.tsv"
    else
        echo "No failed actions in that run."
    fi
}

# Copies back the config files the last run saved. Accounts, packages, stopped services,
# and deleted files are not restored, so those need a hand fix.
undo_last_run() {
    local last b pair name dest
    last=$(latest_run)
    if [ -z "$last" ] || [ ! -d "$last/backup" ]; then
        echo "No backup from a previous run found in $REPORT_DIR."
        return 1
    fi
    b="$last/backup"
    echo "Undo: putting back the config files saved by $last"
    for pair in login.defs:/etc/login.defs \
                pwquality.conf:/etc/security/pwquality.conf \
                faillock.conf:/etc/security/faillock.conf \
                sshd_config:/etc/ssh/sshd_config \
                ufw:/etc/default/ufw \
                common-password:/etc/pam.d/common-password; do
        name=${pair%%:*}
        dest=${pair#*:}
        if [ -f "$b/$name" ] && cp -a "$b/$name" "$dest"; then
            echo "    restored $dest"
        fi
    done
    if [ -d "$b/sshd_config.d" ]; then
        cp -a "$b/sshd_config.d/." /etc/ssh/sshd_config.d/ && echo "    restored /etc/ssh/sshd_config.d"
    fi
    if [ -d "$b/sysctl.d" ]; then
        rm -f /etc/sysctl.d/99-cp-hardening.conf
        cp -a "$b/sysctl.d/." /etc/sysctl.d/ && echo "    restored /etc/sysctl.d"
    fi
    # Drop-ins the toolkit creates (not in the backup, so they would otherwise stay).
    rm -f /etc/lightdm/lightdm.conf.d/50-no-guest.conf /etc/audit/rules.d/cp-toolkit.rules
    echo "Not restored: account changes, removed packages, stopped services, deleted files, and firewall rules."
    echo "To apply the restored settings now: sudo sysctl --system, then restart ssh if you changed it."
}

[ "$(id -u)" -eq 0 ] || { echo "Run with sudo"; exit 1; }
command -v apt-get >/dev/null || { echo "This toolkit needs an apt-based system"; exit 1; }

if [ "$RESULTS" -eq 1 ]; then show_last_results; exit $?; fi
if [ "$UNDO" -eq 1 ]; then undo_last_run; exit $?; fi

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

N=0
for m in $MODULES; do
    want "$m" || continue
    N=$((N + 1))
    if [ -e "$REPORT_DIR/STOP" ]; then
        echo "STOP file found in $REPORT_DIR. Halting before step $N ($m)."
        log STOP "halted before $m"
        break
    fi
    echo
    echo "=== Step $N: $m ==="
    if [ "$ASK" -eq 1 ] && ! ask_yn "Run this step: $(step_desc "$m")?"; then
        echo "    skipped: $m"
        log INFO "step skipped: $m"
        continue
    fi
    # shellcheck source=/dev/null
    . "$DIR/modules/$m.sh"
    if ! ( "mod_$m" ); then
        echo "[*] module $m failed (see run.log). Continuing."
        log ERROR "module $m failed"
        record FAILED "module $m"
    fi
    if [ "$ASK" -eq 0 ] && [ "$NOPAUSE" -eq 0 ] && [ -t 0 ]; then
        read -r -p "Press Enter for the next step... " _
    fi
done

write_summary
[ "$APPLY" -eq 1 ] || echo "Dry run only. Re-run with --apply to make changes."
