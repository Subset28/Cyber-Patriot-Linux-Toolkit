# shellcheck shell=bash
# Ownership and mode of account database files.

mod_perms() {
    say "Permissions"
    act "root ownership of /etc/passwd and /etc/group" chown root:root /etc/passwd /etc/group
    act "mode 644 on /etc/passwd and /etc/group" chmod 644 /etc/passwd /etc/group
    act "root:shadow ownership of /etc/shadow and /etc/gshadow" chown root:shadow /etc/shadow /etc/gshadow
    act "mode 640 on /etc/shadow and /etc/gshadow" chmod 640 /etc/shadow /etc/gshadow
}
