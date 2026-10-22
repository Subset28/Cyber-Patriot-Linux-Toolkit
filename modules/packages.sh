# shellcheck shell=bash
# Prohibited software. Lists installed packages named in the README's prohibited section or in BAD_PKGS,
# and removes only the ones you pick. Protected packages are never offered. Programs that are not packages (launchers and
# binaries, such as a program copied in by hand) are checked too, in prohibited_files.

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

packages_installed() {
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

# Launchers and binaries named like a prohibited program, in the places programs are started from. Some programs
# are not packages, so dpkg does not list them. Nothing is removed without a pick.
prohibited_files() {
    say "Prohibited programs as files and launchers (you pick what to remove)"
    local readme_names n f
    local -a hits=() labels=() picked=()
    readme_names=$(prohibited_readme_names)
    for n in $readme_names $BAD_PKGS; do
        while IFS= read -r f; do
            [ -n "$f" ] || continue
            case "$f" in *cp-toolkit*|*CyberPatriot*|*/cp-reports/*) continue ;; esac
            hits+=("$f")
        done < <(find /usr/share/applications /usr/local/share/applications /opt /usr/bin /usr/sbin /usr/local/bin \
            /usr/local/sbin /home/*/Desktop /home/*/.local/share/applications /root/Desktop -maxdepth 3 \
            \( -iname "*${n}*.desktop" -o -iname "${n}" -o -iname "${n}.*" \) 2>/dev/null)
    done
    if [ "${#hits[@]}" -eq 0 ]; then
        echo "    no prohibited program files or launchers found"
        return 0
    fi
    mapfile -t labels < <(printf '%s\n' "${hits[@]}" | awk '!seen[$0]++')
    echo "    ${#labels[@]} file(s) or launcher(s) that look like prohibited programs:"
    if [ "$APPLY" -ne 1 ]; then
        printf '      %s\n' "${labels[@]}"
        echo "    [dry-run] in apply mode you pick which to remove (a copy is saved first)"
        return 0
    fi
    mapfile -t picked < <(pick_numbers "Remove which of these? (numbers separated by commas, or type none)" "${labels[@]}")
    mkdir -p "$RUN_DIR/deleted-copies"
    for f in "${picked[@]}"; do
        [ -n "$f" ] || continue
        if [ -e "$f" ]; then cp -a -- "$f" "$RUN_DIR/deleted-copies/" 2>/dev/null; fi
        act "remove $f" rm -f -- "$f"
    done
    echo "    files you did not pick are kept"
}

mod_packages() {
    packages_installed
    prohibited_files
}
