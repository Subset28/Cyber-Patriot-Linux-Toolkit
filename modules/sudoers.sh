# shellcheck shell=bash
# Sudo rules that skip the password (NOPASSWD). Lists each one, and removes the NOPASSWD tag only for the
# ones you pick. Every edit is checked with visudo before it replaces the real file, so a bad edit cannot
# break sudo for the admins.

mod_sudoers() {
    say "Sudo: rules that skip the password (you pick which to require a password for)"
    local -a labels=() picked=()
    local mode
    local f ln text label tmp
    # Sudo files must be mode 0440. visudo reports other modes, and the file is not trusted as it should be.
    for f in /etc/sudoers /etc/sudoers.d/*; do
        [ -f "$f" ] || continue
        mode=$(stat -c %a "$f" 2>/dev/null)
        if [ -n "$mode" ] && [ "$mode" != 440 ]; then
            act "set mode 0440 on $f (it was $mode; visudo reports bad permissions)" chmod 0440 "$f"
        fi
    done
    for f in /etc/sudoers /etc/sudoers.d/*; do
        [ -f "$f" ] || continue
        while IFS=: read -r ln text; do
            [ -n "$ln" ] || continue
            labels+=("$f:$ln: $(echo "$text" | sed 's/^[[:space:]]*//')")
        done < <(grep -n -E '^[[:space:]]*[^#[:space:]].*NOPASSWD' "$f" 2>/dev/null)
    done

    if [ "${#labels[@]}" -eq 0 ]; then
        echo "    no NOPASSWD rules found in /etc/sudoers or /etc/sudoers.d"
        return 0
    fi
    echo "    ${#labels[@]} rule(s) skip the password:"
    if [ "$APPLY" -ne 1 ]; then
        printf '      %s\n' "${labels[@]}"
        echo "    [dry-run] in apply mode you pick which rules to require a password for"
        return 0
    fi

    mapfile -t picked < <(pick_numbers "Require a password for which of these? (numbers separated by commas, or type none)" "${labels[@]}")
    mkdir -p "$RUN_DIR/backup"
    for label in "${picked[@]}"; do
        [ -n "$label" ] || continue
        f=${label%%:*}
        ln=${label#*:}
        ln=${ln%%:*}
        tmp=$(mktemp) || { echo "    [FAILED] could not create a temp file for $f"; continue; }
        cp -- "$f" "$tmp"
        sed -i -E "${ln}s/NOPASSWD:[[:space:]]*//" "$tmp"
        if ! visudo -cf "$tmp" >/dev/null 2>&1; then
            echo "    [FAILED] the edited copy of $f did not pass visudo. Nothing changed in $f."
            log FAILED "sudoers edit rejected by visudo: $f line $ln"
            record FAILED "require password in $f line $ln (visudo rejected the edit)"
            rm -f "$tmp"
            continue
        fi
        cp -a -- "$f" "$RUN_DIR/backup/" 2>/dev/null
        act "require a password for sudo in $f line $ln" install -m 0440 -o root -g root "$tmp" "$f"
        rm -f "$tmp"
    done
    echo "    rules you did not pick keep NOPASSWD"
}
