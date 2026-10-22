#!/bin/bash
# Menu for the CyberPatriot Linux toolkit. Start with: sudo bash cp_menu.sh
# Same options as the Windows Run-Menu: Start, Practice run, Show results, Undo, Quit.
DIR=$(cd "$(dirname "$0")" && pwd)
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo: sudo bash cp_menu.sh"; exit 1; }

confirm() { # exact word required before changes are made
    local word=$1 ans
    read -r -p "Type $word to continue, anything else cancels: " ans
    [ "$ans" = "$word" ]
}

while true; do
    echo
    echo "=== CyberPatriot Linux toolkit ==="
    echo "  1) Start: run every step on this PC (asks before each step; type APPLY to confirm)"
    echo "  2) Practice run: the same steps, nothing is changed (asks before each step)"
    echo "  3) Show the last run's results and any failed actions"
    echo "  4) Undo: put back the config files saved by the last run"
    echo "  5) Quit"
    read -r -p "Choice: " choice
    case "$choice" in
        1) if confirm APPLY; then bash "$DIR/cp_harden.sh" --apply --ask; else echo "Cancelled."; fi ;;
        2) bash "$DIR/cp_harden.sh" --ask ;;
        3) bash "$DIR/cp_harden.sh" --results ;;
        4) if confirm UNDO; then bash "$DIR/cp_harden.sh" --undo; else echo "Cancelled."; fi ;;
        5) exit 0 ;;
        *) echo "Pick a number from the list." ;;
    esac
done
