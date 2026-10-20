# shellcheck shell=bash
# Report only. Saves file lists under REPORT_DIR and prints a summary.

mod_audit() {
    mkdir -p "$REPORT_DIR"
    say "Audit (report only, saved under $REPORT_DIR)"

    echo "    $ADMIN_GROUP group: $(getent group "$ADMIN_GROUP" | cut -d: -f4)"
    echo "    UID 0 accounts: $(awk -F: '$3==0{print $1}' /etc/passwd | tr '\n' ' ')"
    awk -F: '$4==0 && $1!="root"{print "    GID 0 member: "$1}' /etc/passwd
    awk -F: '$2==""{print "    empty password: "$1}' /etc/shadow
    echo "    account password status (non-P entries):"
    getent passwd | cut -d: -f1 | while read -r u; do passwd -S "$u" 2>/dev/null | awk '$2!="P"{print "      "$0}'; done

    echo "    sudoers NOPASSWD entries (edit with visudo):"
    grep -rn 'NOPASSWD' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | sed 's/^/      /'

    echo "    ufw: $(ufw status 2>/dev/null | head -n 1)"
    echo "    effective sshd settings:"
    sshd -T 2>/dev/null | grep -iE '^(permitrootlogin|permitemptypasswords|passwordauthentication) ' | sed 's/^/      /'
    grep -q pam_pwquality /etc/pam.d/common-password 2>/dev/null || echo "    pam_pwquality is not in common-password"

    echo "    open ports:"
    ss -tulpn 2>/dev/null | sed 's/^/      /'
    echo "    running services:"
    systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{print "      "$1}'

    find / -xdev -type f -perm -4000 2>/dev/null > "$REPORT_DIR/suid.txt"
    echo "    SUID binaries: $(wc -l < "$REPORT_DIR/suid.txt") (list in $REPORT_DIR/suid.txt)"
    find / -xdev -type f -perm -0002 2>/dev/null | grep -vE '^/(proc|sys|dev|tmp|run)' | head -n 50 > "$REPORT_DIR/world-writable.txt"
    echo "    world-writable files: $(wc -l < "$REPORT_DIR/world-writable.txt") (list in $REPORT_DIR/world-writable.txt)"

    echo "    cron:"
    for f in /etc/crontab /etc/cron.d/*; do [ -f "$f" ] && sed "s|^|      $f: |" "$f"; done
    getent passwd | cut -d: -f1 | while read -r u; do
        crontab -l -u "$u" 2>/dev/null | sed "s/^/      $u: /"
    done

    echo "    browsers: $(command -v chromium chromium-browser firefox 2>/dev/null | tr '\n' ' ')"
    echo "    display manager: ${DM:-unknown}"
    echo "    manual: forensics questions (Desktop only), CCS Client service (do not touch), Update Manager automation checkbox"
}
