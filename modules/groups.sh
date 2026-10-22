# shellcheck shell=bash
# SC2154: GroupMembers comes from config.env, sourced before this file.
# shellcheck disable=SC2154
# Group membership from GroupMembers, plus README-mentioned groups that do not exist.

mod_groups() {
    say "Group membership"
    local pair u g
    for pair in "${GroupMembers[@]}"; do
        u=${pair%%:*}
        g=${pair#*:}
        if ! getent group "$g" >/dev/null; then
            echo "    MISSING group: $g"
            log WARN "missing group $g"
            continue
        fi
        if ! id "$u" >/dev/null 2>&1; then
            echo "    MISSING user: $u (cannot add to $g)"
            log WARN "missing user $u for group $g"
            continue
        fi
        if id -nG "$u" | grep -qw "$g"; then
            echo "    already in $g: $u"
            continue
        fi
        act "add $u to group $g" gpasswd -a "$u" "$g" --fallback usermod -aG "$g" "$u"
    done

    if [ -n "${README:-}" ] && [ -f "$README" ]; then
        say "Groups mentioned in the README (verify by hand)"
        tr -d '\r' < "$README" | grep -ioE '(group|groups)[: ]+[A-Za-z0-9_.-]+' | awk '{print $NF}' | sort -u |
            while read -r g; do
                getent group "$g" >/dev/null || echo "    README names group '$g' but it does not exist"
            done
    fi
}
