# shellcheck shell=bash
# Media files. Lists everything; deletes only files inside a Music folder.

mod_media() {
    say "Media files"
    local list="$RUN_DIR/media.txt"
    find /home /root -xdev -type f -regextype posix-extended -iregex ".*\.($MEDIA_EXT)$" 2>/dev/null > "$list"
    local n
    n=$(wc -l < "$list")
    echo "    found $n media files (list in $list)"
    log INFO "media files found: $n"
    find /home /root -xdev -type f -regextype posix-extended -iregex ".*/($MEDIA_DIRS)/.*\.($MEDIA_EXT)$" -print0 2>/dev/null |
        while IFS= read -r -d '' f; do
            echo "    non-work media: $f"
            act "delete $f" rm -f -- "$f"
        done
}
