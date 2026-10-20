# shellcheck shell=bash
# Things to check by hand, with a pick list for each. Nothing is stopped or removed without your pick.
#   1. Files at the top of / that do not belong there
#   2. Running programs started from user, temp, or hidden folders
#   3. Listening ports that are not in the README's critical services or the usual set

mod_review() {
    say "Top of / and running programs (you pick what to remove or stop)"

    # 1. Top of /
    local -a top=()
    local f
    while IFS= read -r f; do top+=("$f"); done < <(find / -mindepth 1 -maxdepth 1 -type f 2>/dev/null | sort)
    if [ "${#top[@]}" -eq 0 ]; then
        echo "    no loose files at the top of /"
    else
        echo "    loose files at the top of / (not normal for a system folder):"
        printf '      %s\n' "${top[@]}"
        if [ "$APPLY" -eq 1 ]; then
            local -a picked=()
            mapfile -t picked < <(pick_numbers "Delete which of these? (numbers separated by commas, or type none)" "${top[@]}")
            local p
            for p in "${picked[@]}"; do [ -n "$p" ] && act "delete $p" rm -f -- "$p"; done
        fi
    fi

    # 2. Running programs from user, temp, or hidden folders
    local -a procs=()
    local pid exe
    for pid in $(ps -eo pid= 2>/dev/null); do
        exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null) || continue
        case "$exe" in
            /home/*|/tmp/*|/var/tmp/*|/dev/shm/*|/run/user/*) procs+=("$pid  $exe") ;;
        esac
    done
    if [ "${#procs[@]}" -eq 0 ]; then
        echo "    no running programs from user, temp, or hidden folders"
    else
        echo "    running programs from user, temp, or hidden folders:"
        printf '      %s\n' "${procs[@]}"
        if [ "$APPLY" -eq 1 ]; then
            local -a picked=()
            mapfile -t picked < <(pick_numbers "Stop which of these? (numbers separated by commas, or type none)" "${procs[@]}")
            local line
            for line in "${picked[@]}"; do
                [ -n "$line" ] || continue
                pid=${line%% *}
                act "stop process $pid ($line)" kill -- "$pid"
            done
        fi
    fi

    # 3. Listening ports (report only: stopping a listener can break a required service)
    echo "    listening ports (check each one you do not recognize):"
    ss -tulpn 2>/dev/null | awk 'NR>1 {print "      " $0}' | head -n 30
    echo "    full listing is in the audit module's report"
}
