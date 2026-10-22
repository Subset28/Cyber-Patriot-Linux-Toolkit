# shellcheck shell=bash
# Package updates and automatic security updates. Every apt step shows its output on screen and saves it to
# apt.log in the run folder, so a failure or a long wait is visible.

APT_OPTS=(-o Dpkg::Options::=--force-confold -o DPkg::Lock::Timeout=600)

# Number of packages apt can upgrade right now.
upgradable_count() {
    apt list --upgradable 2>/dev/null | grep -c '/' || true
}

# Runs one apt command with output on screen and in apt.log. Prints the result and the last lines on failure.
apt_step() {
    local desc=$1; shift
    echo "    running: $desc"
    "$@" 2>&1 | tee -a "$RUN_DIR/apt.log"
    local rc=${PIPESTATUS[0]}
    if [ "$rc" -eq 0 ]; then
        echo "    [ok] $desc"
        log OK "$desc"
        record OK "$desc"
    else
        echo "    [FAILED] $desc (exit $rc). Last lines of apt.log:"
        tail -n 8 "$RUN_DIR/apt.log" | sed 's/^/        /'
        log FAILED "$desc (exit $rc)"
        record FAILED "$desc"
    fi
    return "$rc"
}

# Writes a root-owned file (used for apt configuration). Dry run prints what would be written.
write_root_file() {
    local path=$1 content=$2
    act "write $path" sh -c 'printf "%s\n" "$1" > "$2"' _ "$content" "$path"
}

mod_updates() {
    say "Updates"
    if [ "$APPLY" -ne 1 ]; then
        echo "    [dry-run] apt-get update, then full-upgrade (existing config files kept)"
        echo "    [dry-run] upgradable packages now: $(upgradable_count)"
        echo "    [dry-run] turn on automatic security updates (apt periodic and unattended-upgrades)"
        return 0
    fi
    mkdir -p "$RUN_DIR"
    echo "    apt waits up to 10 minutes if another apt or dpkg process (such as unattended-upgrades) is running."
    apt_step "refresh package lists" apt-get "${APT_OPTS[@]}" update
    echo "    upgradable packages before: $(upgradable_count)"
    apt_step "full-upgrade (existing config files kept)" env DEBIAN_FRONTEND=noninteractive apt-get -y "${APT_OPTS[@]}" full-upgrade
    local left
    left=$(upgradable_count)
    if [ "$left" -gt 0 ]; then
        echo "    [CHECK] $left package(s) still upgradable after the upgrade. See $RUN_DIR/apt.log"
        log WARN "$left packages still upgradable"
        record FAILED "packages still upgradable after full-upgrade: $left"
    else
        echo "    no packages are left to upgrade"
    fi

    act "install unattended-upgrades" apt-get "${APT_OPTS[@]}" install -y unattended-upgrades --fallback dpkg --configure -a
    act "turn on automatic security updates (apt periodic)" \
        sh -c 'printf "APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n" > /etc/apt/apt.conf.d/20auto-upgrades'
    write_root_file /etc/apt/apt.conf.d/52cp-security-updates 'Unattended-Upgrade::Allowed-Origins:: "${distro_id}:${distro_codename}-security";'
}
