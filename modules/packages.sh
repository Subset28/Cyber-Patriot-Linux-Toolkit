# shellcheck shell=bash
# Prohibited software. Lists what is installed, and you pick what to remove.
# Protected packages are never offered.

protected_pkg() {
    inlist "$PROTECTED_PKGS" "$1" && return 0
    case "$1" in openssh-*|chromium*|lightdm*|firefox*) return 0 ;; esac
    return 1
}

mod_packages() {
    say "Prohibited software (you pick what to remove)"
    local -a found=() removable=() picked=()
    local p pkg
    mapfile -t found < <(for p in $BAD_PKGS; do dpkg-query -W -f='${Package}\n' "$p" "$p-*" 2>/dev/null; done | awk '!seen[$0]++')
    for pkg in "${found[@]}"; do
        if protected_pkg "$pkg"; then
            echo "    protected, not offered: $pkg"
            log INFO "protected package skipped: $pkg"
            continue
        fi
        removable+=("$pkg")
    done

    if [ "${#removable[@]}" -eq 0 ]; then
        echo "    no prohibited software installed"
        return 0
    fi
    echo "    ${#removable[@]} prohibited package(s) installed:"
    if [ "$APPLY" -ne 1 ]; then
        printf '    %s\n' "${removable[@]}"
        echo "    [dry-run] in apply mode you pick which packages to remove"
        return 0
    fi
    mapfile -t picked < <(pick_numbers "Remove which of these? (numbers separated by commas, or type none)" "${removable[@]}")
    for pkg in "${picked[@]}"; do
        [ -n "$pkg" ] || continue
        act "purge $pkg" apt-get purge -y "$pkg" --fallback dpkg --purge "$pkg"
    done
    echo "    packages you did not pick are kept"
}
