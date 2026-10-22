# shellcheck shell=bash
# Prohibited software. Lists installed packages named in the README's prohibited section or in BAD_PKGS,
# and removes only the ones you pick. Protected packages are never offered.

protected_pkg() {
    inlist "$PROTECTED_PKGS" "$1" && return 0
    case "$1" in openssh-*|chromium*|lightdm*|firefox*) return 0 ;; esac
    return 1
}

# Names from the README's prohibited section, space-separated. Empty when the README has none or was not read.
prohibited_readme_names() {
    [ -n "${README:-}" ] && [ -f "$README" ] || return 0
    parse_section '[Pp]rohibited' '^[[:space:]]*([Aa]uthorized|[Rr]equired|[Cc]ritical|[Ff]orensic|[Cc]ompetition|[Nn]ote)'
}

mod_packages() {
    say "Prohibited software (you pick what to remove)"
    local readme_names n pkg src label
    local -a removable=() labels=() picked=()
    local -A seen=()
    readme_names=$(prohibited_readme_names)
    [ -n "$readme_names" ] && echo "    named in the README: $readme_names"

    for n in $readme_names $BAD_PKGS; do
        # Exact name, or name-something (for example nmap and nmap-common).
        while IFS= read -r pkg; do
            [ -n "$pkg" ] || continue
            [ -n "${seen[$pkg]:-}" ] && continue
            seen[$pkg]=1
            if protected_pkg "$pkg"; then
                echo "    protected, not offered: $pkg"
                log INFO "protected package skipped: $pkg"
                continue
            fi
            if inlist "$readme_names" "$n"; then src="named in README"; else src="built-in list"; fi
            removable+=("$pkg")
            labels+=("$pkg  (matched '$n', $src)")
        done < <(dpkg-query -W -f='${Package}\n' 2>/dev/null | awk -v w="${n,,}" 'tolower($0) == w || index(tolower($0), w "-") == 1')
    done

    # A README name that matches no installed package is reported, so it is not dropped without a word.
    for n in $readme_names; do
        if ! dpkg-query -W -f='${Package}\n' 2>/dev/null | awk -v w="${n,,}" 'tolower($0) == w || index(tolower($0), w "-") == 1' | grep -q .; then
            echo "    not installed (or named differently on this system, check by hand): $n"
        fi
    done

    if [ "${#removable[@]}" -eq 0 ]; then
        echo "    no prohibited software installed"
        return 0
    fi
    echo "    ${#removable[@]} prohibited package(s) installed:"
    if [ "$APPLY" -ne 1 ]; then
        printf '      %s\n' "${labels[@]}"
        echo "    [dry-run] in apply mode you pick which packages to remove"
        return 0
    fi
    mapfile -t picked < <(pick_numbers "Remove which of these? (numbers separated by commas, or type none)" "${labels[@]}")
    for label in "${picked[@]}"; do
        [ -n "$label" ] || continue
        pkg=${label%%  *}
        act "purge $pkg" apt-get purge -y "$pkg" --fallback dpkg --purge "$pkg"
    done
    echo "    packages you did not pick are kept"
}
