# shellcheck shell=bash
# Remove prohibited software. Protected packages are never touched.

protected_pkg() {
    inlist "$PROTECTED_PKGS" "$1" && return 0
    case "$1" in openssh-*|chromium*|lightdm*|firefox*) return 0 ;; esac
    return 1
}

mod_packages() {
    say "Prohibited software"
    for p in $BAD_PKGS; do
        for pkg in $(dpkg-query -W -f='${Package}\n' "$p" "$p-*" 2>/dev/null); do
            if protected_pkg "$pkg"; then
                echo "    skipping protected package: $pkg"
                log INFO "protected package skipped: $pkg"
                continue
            fi
            echo "    installed: $pkg"
            act "purge $pkg" apt-get purge -y "$pkg" --fallback dpkg --purge "$pkg"
        done
    done
}
