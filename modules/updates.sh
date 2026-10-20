# shellcheck shell=bash
# Package updates and automatic security updates.

mod_updates() {
    say "Updates"
    act "refresh package lists" apt-get update
    act "full-upgrade, keeping existing config files" \
        apt-get -y -o Dpkg::Options::=--force-confold full-upgrade \
        --fallback apt-get -y -o Dpkg::Options::=--force-confold upgrade
    act "install unattended-upgrades" apt-get install -y unattended-upgrades --fallback dpkg --configure -a
    act "turn on automatic security updates" \
        sh -c 'printf "APT::Periodic::Update-Package-Lists \"1\";\nAPT::Periodic::Unattended-Upgrade \"1\";\n" > /etc/apt/apt.conf.d/20auto-upgrades' \
        --fallback dpkg-reconfigure -f noninteractive unattended-upgrades
}
