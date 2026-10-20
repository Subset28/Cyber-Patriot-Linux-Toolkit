# shellcheck shell=bash
# Scripts, executables, and known hacking tools in user folders. You pick which ones to remove.

SUSPICIOUS_EXT_RE='\.(sh|py|pl|rb|exe|bat|cmd|ps1|jar|apk)$'
TOOL_NAME_RE='(^|/)(nmap|zenmap|john|hydra|nikto|aircrack|ophcrack|wireshark|netcat|nc|metasploit|sqlmap|burp|cain|wifite|ettercap|hping)[^/]*$'

mod_userfiles() {
    say "User folders: scripts, executables, and known hacking tools"
    local -a flagged=()
    local f
    while IFS= read -r f; do
        # Our own toolkit and competition folders are never flagged.
        case "$f" in *cp-toolkit*|*/cp-reports/*|*CyberPatriot*) continue ;; esac
        flagged+=("$f")
    done < <(find /home /root -maxdepth 4 -type f \( -regextype posix-extended -iregex ".*$SUSPICIOUS_EXT_RE" -o -regextype posix-extended -iregex ".*$TOOL_NAME_RE" \) \
        -not -path '*/.cache/*' -not -path '*/.local/share/*' -not -path '*/snap/*' 2>/dev/null)

    if [ "${#flagged[@]}" -eq 0 ]; then
        echo "    no suspicious files found in the user folders"
        return 0
    fi
    local list="$RUN_DIR/suspicious-files.txt"
    printf '%s\n' "${flagged[@]}" > "$list"
    echo "    ${#flagged[@]} suspicious file(s). Full list: $list"
    log INFO "suspicious user files: ${#flagged[@]}"

    if [ "$APPLY" -ne 1 ]; then
        printf '    %s\n' "${flagged[@]}"
        echo "    [dry-run] in apply mode you pick which files to remove"
        return 0
    fi
    local -a picked=()
    mapfile -t picked < <(pick_numbers "Remove which of these files? (numbers separated by commas, or type none)" "${flagged[@]}")
    for f in "${picked[@]}"; do
        [ -n "$f" ] || continue
        act "remove $f" rm -f -- "$f"
    done
    echo "    files you did not pick are kept"
}
