#!/bin/bash
# Menu for the CyberPatriot Linux toolkit. Start with: sudo bash cp_menu.sh
DIR=$(cd "$(dirname "$0")" && pwd)
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo: sudo bash cp_menu.sh"; exit 1; }

confirm() { # exact word required before changes are made
    local word=$1 ans
    read -r -p "Type $word to continue, anything else cancels: " ans
    [ "$ans" = "$word" ]
}

pick_modules() {
    echo "Modules: $(bash "$DIR/cp_harden.sh" --list | tr '\n' ' ')"
    read -r -p "Comma-separated modules to run: " MODS
}

while true; do
    echo
    echo "=== CyberPatriot Linux toolkit ==="
    echo "  1) Show users, admins, and services from the README (no changes)"
    echo "  2) Dry run, all modules (no changes)"
    echo "  3) APPLY, all modules (makes changes)"
    echo "  4) Dry run, pick modules"
    echo "  5) APPLY, pick modules (makes changes)"
    echo "  6) Emergency stop (halts before the next module)"
    echo "  7) Quit"
    read -r -p "Choice: " choice
    case "$choice" in
        1) bash "$DIR/cp_harden.sh" --show ;;
        2) bash "$DIR/cp_harden.sh" ;;
        3) if confirm APPLY; then bash "$DIR/cp_harden.sh" --apply; else echo "Cancelled."; fi ;;
        4) pick_modules; bash "$DIR/cp_harden.sh" --only "$MODS" ;;
        5) pick_modules
           if confirm APPLY; then bash "$DIR/cp_harden.sh" --only "$MODS" --apply; else echo "Cancelled."; fi ;;
        6) mkdir -p /root/cp-reports && touch /root/cp-reports/STOP && echo "STOP file created." ;;
        7) exit 0 ;;
        *) echo "Pick a number from the list." ;;
    esac
done
