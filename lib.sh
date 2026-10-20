#!/bin/bash
# Shared helpers for cp_harden.sh and modules/. Sourced, not run directly.

: "${APPLY:=0}"
: "${REPORT_DIR:=/root/cp-reports}"
: "${RUN_DIR:=}"

log() {
    [ -n "$RUN_DIR" ] || return 0
    printf '%s [%s] %s\n' "$(date '+%F %T')" "$1" "$2" >> "$RUN_DIR/run.log"
}

record() {
    [ -n "$RUN_DIR" ] || return 0
    printf '%s\t%s\n' "$1" "$2" >> "$RUN_DIR/results.tsv"
}

say() {
    echo "[*] $*"
    log INFO "$*"
}

inlist() { case " $1 " in *" $2 "*) return 0 ;; esac; return 1; }

ask() { local a; read -r -p "$1" a; echo "$a"; }

# ask_yn QUESTION -> returns 0 for y, 1 for n. Enter alone does not answer.
ask_yn() {
    local a
    while :; do
        read -r -p "$1 (y/n): " a
        case "$a" in
            y|Y|yes) return 0 ;;
            n|N|no)  return 1 ;;
            *) echo "    Type y or n. Enter alone does not continue." ;;
        esac
    done
}

# Prints the newest run folder under REPORT_DIR, if there is one.
latest_run() {
    ls -1dt "$REPORT_DIR"/run-* 2>/dev/null | head -n 1
}

# pick_numbers QUESTION ITEM...  -> prints the chosen items, one per line.
# Enter alone does not answer: type numbers (commas or spaces), or 'none'.
pick_numbers() {
    local question=$1; shift
    local -a items=("$@")
    local i answer part valid
    # The list and messages go to stderr, so only the chosen items reach stdout for the caller.
    for ((i = 0; i < ${#items[@]}; i++)); do printf '    %3d) %s\n' "$((i + 1))" "${items[i]}" >&2; done
    while :; do
        read -r -p "$question: " answer
        answer=${answer//,/ }
        if [ -z "$answer" ]; then
            echo "    Type numbers from 1 to ${#items[@]}, or type none. Enter alone does not continue." >&2
            continue
        fi
        if [ "$answer" = none ] || [ "$answer" = 0 ]; then return 0; fi
        valid=1
        for part in $answer; do
            if ! [[ $part =~ ^[0-9]+$ ]] || [ "$part" -lt 1 ] || [ "$part" -gt "${#items[@]}" ]; then valid=0; fi
        done
        if [ "$valid" -eq 1 ]; then
            for part in $answer; do printf '%s\n' "${items[part - 1]}"; done | awk '!seen[$0]++'
            return 0
        fi
        echo "    Type numbers from 1 to ${#items[@]}, separated by commas, or type none." >&2
    done
}

# act DESC PRIMARY_ARGV... [--fallback FALLBACK_ARGV...]
# Runs the primary command. If it fails and a fallback is given, runs the fallback.
# Output goes to commands.log so the console stays readable.
act() {
    local desc=$1; shift
    local -a p=() f=()
    local split=0 a
    for a in "$@"; do
        if [ "$a" = "--fallback" ] && [ "$split" -eq 0 ]; then split=1; continue; fi
        if [ "$split" -eq 0 ]; then p+=("$a"); else f+=("$a"); fi
    done
    if [ "$APPLY" -ne 1 ]; then
        echo "    [dry-run] $desc"
        log DRY "$desc"
        return 0
    fi
    if "${p[@]}" >>"$RUN_DIR/commands.log" 2>&1; then
        echo "    [ok] $desc"
        log OK "$desc"
        record OK "$desc"
        return 0
    fi
    log WARN "primary failed: ${p[*]}"
    if [ "${#f[@]}" -gt 0 ] && "${f[@]}" >>"$RUN_DIR/commands.log" 2>&1; then
        echo "    [ok via fallback] $desc"
        log FALLBACK "$desc"
        record FALLBACK "$desc"
        return 0
    fi
    echo "    [FAILED] $desc"
    log FAILED "$desc"
    record FAILED "$desc"
    return 1
}

# For commands that prompt on the terminal (passwd, useradd): no output capture, no fallback.
tty_run() {
    local desc=$1; shift
    if [ "$APPLY" -ne 1 ]; then
        echo "    [dry-run] $desc"
        log DRY "$desc"
        return 0
    fi
    if "$@"; then
        echo "    [ok] $desc"
        log OK "$desc"
        record OK "$desc"
        return 0
    fi
    echo "    [FAILED] $desc"
    log FAILED "$desc"
    record FAILED "$desc"
    return 1
}

setline() { # file key full_line
    local f=$1 k=$2 line=$3
    [ -f "$f" ] || { echo "    missing $f, skipping"; log WARN "missing $f"; return 1; }
    if grep -qE "^[# ]*$k\b" "$f"; then
        act "set $k in $f" \
            sed -i -E "s|^[# ]*$k\b.*|$line|" "$f" \
            --fallback sh -c 'sed -i -E "/^[# ]*$1\\b/d" "$2" && printf "%s\n" "$3" >> "$2"' _ "$k" "$f" "$line"
    else
        act "append $k to $f" sh -c 'printf "%s\n" "$1" >> "$2"' _ "$line" "$f"
    fi
}

# Random 16-character password with upper, lower, digit, and symbol (no ':' or quotes, so chpasswd is safe).
gen_password() {
    local p sym='[!#%^&*_=+-]'
    while :; do
        p=$(tr -dc 'A-Za-z0-9!#%^&*_=+-' < /dev/urandom | head -c 16)
        [[ $p =~ [A-Z] && $p =~ [a-z] && $p =~ [0-9] && $p =~ $sym ]] && break
    done
    printf '%s' "$p"
}

# Sets a generated password and saves it to new-passwords.txt in the run folder (not shown on screen).
# Does not use act(): act() logs its arguments, and that would write the password to run.log.
set_generated_password() {
    local u=$1 p
    if [ "$APPLY" -ne 1 ]; then
        echo "    [dry-run] set a generated password for $u"
        log DRY "set a generated password for $u"
        return 0
    fi
    p=$(gen_password)
    if printf '%s:%s\n' "$u" "$p" | chpasswd >>"$RUN_DIR/commands.log" 2>&1; then
        printf '%s\t%s\n' "$u" "$p" >> "$RUN_DIR/new-passwords.txt"
        chmod 600 "$RUN_DIR/new-passwords.txt"
        echo "    [ok] set a generated password for $u (saved to the run folder)"
        log OK "set a generated password for $u"
        record OK "set a generated password for $u"
    else
        echo "    [FAILED] set a generated password for $u"
        log FAILED "set a generated password for $u"
        record FAILED "set a generated password for $u"
    fi
}

save_backups() {
    local b="$RUN_DIR/backup" f
    mkdir -p "$b"
    for f in /etc/passwd /etc/group /etc/shadow /etc/gshadow /etc/login.defs \
             /etc/security/pwquality.conf /etc/security/faillock.conf \
             /etc/ssh/sshd_config /etc/default/ufw; do
        [ -e "$f" ] && cp -a "$f" "$b/" 2>/dev/null
    done
    [ -d /etc/ssh/sshd_config.d ] && cp -a /etc/ssh/sshd_config.d "$b/"
    [ -d /etc/sysctl.d ] && cp -a /etc/sysctl.d "$b/"
    ufw status verbose > "$b/ufw-status.txt" 2>&1
    sysctl -a > "$b/sysctl-a.txt" 2>/dev/null
    dpkg -l > "$b/dpkg-l.txt" 2>/dev/null
    systemctl list-units --type=service --all --no-pager > "$b/systemctl-services.txt" 2>/dev/null
    log INFO "backups saved to $b"
    echo "[*] backups saved to $b"
}

write_summary() {
    local r="$RUN_DIR/results.tsv" ok fb fl failed mode
    ok=$(awk -F'\t' '$1=="OK"{n++} END{print n+0}' "$r" 2>/dev/null)
    fb=$(awk -F'\t' '$1=="FALLBACK"{n++} END{print n+0}' "$r" 2>/dev/null)
    fl=$(awk -F'\t' '$1=="FAILED"{n++} END{print n+0}' "$r" 2>/dev/null)
    failed=$(awk -F'\t' '$1=="FAILED"{gsub(/\\/,"\\\\",$2); gsub(/"/,"\\\"",$2); printf "%s\"%s\"", (n++?",":""), $2}' "$r" 2>/dev/null)
    mode=DRY-RUN
    [ "$APPLY" -eq 1 ] && mode=APPLY
    printf '{\n  "mode": "%s",\n  "finished": "%s",\n  "ok": %s,\n  "fallback": %s,\n  "failed_count": %s,\n  "failed": [%s]\n}\n' \
        "$mode" "$(date '+%F %T')" "${ok:-0}" "${fb:-0}" "${fl:-0}" "$failed" > "$RUN_DIR/summary.json"
    echo ""
    echo "[*] Summary: OK=${ok:-0} FALLBACK=${fb:-0} FAILED=${fl:-0} (details in $RUN_DIR)"
    if [ "${fl:-0}" -gt 0 ]; then
        echo "[*] Failed actions (check by hand):"
        awk -F'\t' '$1=="FAILED"{print "    " $2}' "$r"
    fi
    log INFO "run finished: OK=${ok:-0} FALLBACK=${fb:-0} FAILED=${fl:-0}"
}

find_readme() {
    local f
    for f in /home/*/Desktop/* /root/Desktop/*; do
        case "${f,,}" in
            */readme*.txt|*/readme*.html|*/readme*.htm|*/readme*.md)
                [ -f "$f" ] && { echo "$f"; return; } ;;
            */readme*)
                [ -f "$f" ] && echo "    '$(basename "$f")' is not a text or HTML file, so it was skipped. Save the README as .txt or .html." >&2 ;;
        esac
    done
}

parse_section() { # start_regex end_regex -> space-separated names
    tr -d '\r' < "$README" | sed -e 's/<[^>]*>/\n/g' -e 's/^[[:space:]]*[-*][[:space:]]*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | awk -v s="$1" -v e="$2" '
        $0 ~ s {on=1; next}
        on && $0 ~ e {exit}
        on && NF && tolower($0) !~ /password/ {print $1}
    ' | sed 's/[^A-Za-z0-9_.-].*$//' | grep -E '^[A-Za-z_][A-Za-z0-9_.-]*$' | tr '\n' ' '
}

# Critical services with a looser heading match, and names on the same line as the heading ("Critical Services: DNS, IIS").
parse_services() {
    tr -d '\r' < "$README" | sed -e 's/<[^>]*>/\n/g' | awk '
        { line = $0; gsub(/^[ \t]*[-*][ \t]*/, "", line); gsub(/^[ \t]+|[ \t]+$/, "", line) }
        tolower(line) ~ /^critical services/ && length(line) < 60 {
            on = 1
            if (index(line, ":")) {
                rest = line; sub(/^[^:]*:/, "", rest)
                n = split(rest, parts, /[,;]/)
                for (i = 1; i <= n; i++) { w = parts[i]; gsub(/^[ \t]+|[ \t]+$/, "", w); split(w, t, /[ \t]+/); if (t[1] != "") print t[1] }
            }
            next
        }
        on && tolower(line) ~ /^(authorized|competition|prohibited|forensic|note)/ { exit }
        on && line != "" && tolower(line) !~ /password/ { split(line, t, /[ \t]+/); print t[1] }
    ' | sed 's/[^A-Za-z0-9_.-].*$//' | grep -E '^[A-Za-z_][A-Za-z0-9_.-]*$' | tr '\n' ' '
}

# Shows the lines that mention services, so a README heading that was not matched can be seen.
show_service_lines() {
    echo "    Critical services: no list found. Lines that mention services:"
    tr -d '\r' < "$README" | sed -e 's/<[^>]*>/\n/g' | grep -i 'service' | sed 's/^[[:space:]]*/      /' | head -n 6
}

detect_env() {
    . /etc/os-release
    OS_NAME=${PRETTY_NAME:-unknown}
    ADMIN_GROUP=sudo
    getent group sudo >/dev/null || ADMIN_GROUP=wheel
    DM=$(cat /etc/X11/default-display-manager 2>/dev/null)
    SSH_UNIT=$(systemctl list-unit-files --type=service 2>/dev/null | awk '$1=="ssh.service"||$1=="sshd.service"{sub(/\.service$/,"",$1); print $1; exit}')
}
