# shellcheck shell=bash
# Report only: lists Forensics Question files on the Desktop. Answer them by hand.

mod_forensics() {
    say "Forensics questions (report only)"
    local found=0 d f
    for d in /home/*/Desktop /root/Desktop; do
        [ -d "$d" ] || continue
        while IFS= read -r f; do
            echo "    $f"
            log INFO "forensics file: $f"
            found=$((found + 1))
        done < <(find "$d" -maxdepth 1 -type f -iname 'Forensics Question*' 2>/dev/null)
    done
    if [ "$found" -eq 0 ]; then
        echo "    no Forensics Question files found on any Desktop"
    else
        echo "    Answer each one by hand, and read them before changing anything else."
    fi
}
