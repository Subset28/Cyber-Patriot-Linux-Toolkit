# shellcheck shell=bash
# /etc/hosts: lines that are not the standard entries can redirect sites or block updates. Lists them and
# removes only the lines you pick. The original file is saved to the run folder first.

HOSTS_FILE=${HOSTS_FILE:-/etc/hosts}

# Lines that belong in a default hosts file. Anything else with an address is listed for a decision.
hosts_is_default() {
    case "$1" in
        ''|\#*) return 0 ;;
        127.0.0.1[[:space:]]*localhost*|::1[[:space:]]*localhost*|::1[[:space:]]*ip6-*) return 0 ;;
        fe00::*|ff00::*|ff02::*) return 0 ;;
        127.0.1.1[[:space:]]*) return 0 ;;
        *) return 1 ;;
    esac
}

mod_hosts() {
    say "Hosts file (you pick which non-standard lines to remove)"
    if [ ! -f "$HOSTS_FILE" ]; then
        echo "    $HOSTS_FILE not found"
        return 0
    fi
    local -a labels=() picked=()
    local ln text label
    ln=0
    while IFS= read -r text || [ -n "$text" ]; do
        ln=$((ln + 1))
        hosts_is_default "$text" && continue
        labels+=("line $ln: $text")
    done < "$HOSTS_FILE"

    if [ "${#labels[@]}" -eq 0 ]; then
        echo "    only the standard entries are in $HOSTS_FILE"
        return 0
    fi
    echo "    ${#labels[@]} non-standard line(s) in $HOSTS_FILE:"
    if [ "$APPLY" -ne 1 ]; then
        printf '      %s\n' "${labels[@]}"
        echo "    [dry-run] in apply mode you pick which lines to remove"
        return 0
    fi

    mapfile -t picked < <(pick_numbers "Remove which of these lines? (numbers separated by commas, or type none)" "${labels[@]}")
    local -a nums=()
    for label in "${picked[@]}"; do
        [ -n "$label" ] || continue
        ln=${label#line }
        nums+=("${ln%%:*}")
    done
    [ "${#nums[@]}" -gt 0 ] || { echo "    nothing removed"; return 0; }

    local tmp
    tmp=$(mktemp) || { echo "    [FAILED] could not create a temp file"; return 1; }
    cp -- "$HOSTS_FILE" "$tmp"
    # Delete from the bottom up so earlier line numbers stay correct.
    local n
    for n in $(printf '%s\n' "${nums[@]}" | sort -rn); do
        sed -i "${n}d" "$tmp"
    done
    if [ -n "${RUN_DIR:-}" ]; then
        mkdir -p "$RUN_DIR/backup"
        cp -a -- "$HOSTS_FILE" "$RUN_DIR/backup/hosts" 2>/dev/null
    fi
    act "remove ${#nums[@]} line(s) from $HOSTS_FILE" install -m 0644 -o root -g root "$tmp" "$HOSTS_FILE"
    rm -f -- "$tmp"
    echo "    lines you did not pick are kept"
}
