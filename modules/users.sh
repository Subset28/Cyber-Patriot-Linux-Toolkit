# shellcheck shell=bash
# Users, admin group membership, missing authorized accounts, new admins, and root lock.

mod_users() {
    say "Users and admins"
    local done_users=" "
    local admins_l=" ${ADMINS,,} ${NEW_ADMINS,,} "
    local users_l=" ${USERS,,} ${NewUsers[*],,} "
    getent passwd | while IFS=: read -r name _ uid _ _ _ shell; do
        [ "$name" = root ] && continue
        [ "$uid" -ge 1000 ] || [ "$uid" -eq 0 ] || continue
        case "$shell" in */nologin|*/false) continue ;; esac
        [ "$name" = "${SUDO_USER:-root}" ] && continue
        [ "$uid" -eq 0 ] && echo "    extra UID 0 account: $name"
        lname=${name,,}
        if inlist "$admins_l" "$lname"; then
            id -nG "$name" | grep -qw "$ADMIN_GROUP" || \
                act "add $name to $ADMIN_GROUP" usermod -aG "$ADMIN_GROUP" "$name" --fallback adduser "$name" "$ADMIN_GROUP"
        elif inlist "$users_l" "$lname"; then
            id -nG "$name" | grep -qw "$ADMIN_GROUP" && \
                act "remove admin rights from $name" gpasswd -d "$name" "$ADMIN_GROUP" --fallback deluser "$name" "$ADMIN_GROUP"
        else
            echo "    UNAUTHORIZED: $name"
            if [ -z "${README:-}" ] || [ ! -f "$README" ] || grep -qiw -- "$name" "$README"; then
                echo "    SKIPPED: $name is named in the README, or the README was not read. Not deleting. Check ADMINS/USERS in config.env."
                log WARN "refused to delete $name: named in README or README unavailable"
                continue
            fi
            if [ "$DeleteUnauthorizedHomes" -eq 1 ]; then
                act "delete unauthorized user $name and its home folder" userdel -r "$name" --fallback deluser --remove-home "$name"
            else
                act "delete unauthorized user $name (home folder kept)" userdel "$name" --fallback deluser "$name"
            fi
        fi
    done

    say "Missing authorized accounts (you pick which to create)"
    local -a missing=() picked=()
    local u
    mapfile -t missing < <(for u in $ADMINS $USERS; do id "$u" >/dev/null 2>&1 || echo "$u"; done | awk '!seen[$0]++')
    if [ "${#missing[@]}" -eq 0 ]; then
        echo "    every authorized account exists"
    elif [ "$APPLY" -ne 1 ]; then
        printf '    missing: %s\n' "${missing[@]}"
        echo "    [dry-run] in apply mode you pick which accounts to create"
    else
        mapfile -t picked < <(pick_numbers "Create which of these? (numbers separated by commas, or type none)" "${missing[@]}")
        for u in "${picked[@]}"; do
            [ -n "$u" ] || continue
            act "create user $u" useradd -m -s /bin/bash "$u" || continue
            set_generated_password "$u"
            act "force password change at next login for $u" chage -d 0 "$u"
            if inlist "$admins_l" "${u,,}"; then
                act "add $u to $ADMIN_GROUP" usermod -aG "$ADMIN_GROUP" "$u" --fallback adduser "$u" "$ADMIN_GROUP"
            fi
            done_users+=" $u "
        done
    fi

    say "New standard accounts"
    for u in "${NewUsers[@]}"; do
        if id "$u" >/dev/null 2>&1; then echo "    exists: $u"; continue; fi
        act "create user $u" useradd -m -s /bin/bash "$u" || continue
        set_generated_password "$u"
        act "force password change at next login for $u" chage -d 0 "$u"
        done_users+=" $u "
    done

    say "New admin accounts"
    for u in $NEW_ADMINS; do
        if id "$u" >/dev/null 2>&1; then echo "    exists: $u"; continue; fi
        act "create admin $u" useradd -m -s /bin/bash "$u" || continue
        set_generated_password "$u"
        act "force password change at next login for $u" chage -d 0 "$u"
        act "add $u to $ADMIN_GROUP" usermod -aG "$ADMIN_GROUP" "$u" --fallback adduser "$u" "$ADMIN_GROUP"
        done_users+=" $u "
    done

    say "New passwords for every authorized account (saved to the run folder, not shown on screen)"
    local autologin skip_list=" ${SUDO_USER:-root} root "
    autologin=$(grep -rhs '^[[:space:]]*autologin-user[[:space:]]*=' /etc/lightdm/ 2>/dev/null | tail -n 1 | cut -d= -f2 | tr -d ' \r')
    [ -n "$autologin" ] && skip_list+="$autologin "
    for u in $ADMINS $USERS $NEW_ADMINS "${NewUsers[@]}"; do
        id "$u" >/dev/null 2>&1 || continue
        inlist "$done_users" "$u" && continue
        if inlist "$skip_list" "$u"; then
            echo "    skip: $u (you are logged in as this account, the root account, or the auto-login account)"
            continue
        fi
        set_generated_password "$u"
        act "force password change at next login for $u" chage -d 0 "$u"
    done

    say "Root account"
    act "lock root password (admins use sudo)" passwd -l root --fallback usermod -L root
}
