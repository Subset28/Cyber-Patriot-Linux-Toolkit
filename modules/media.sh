# shellcheck shell=bash
# Media files. Lists everything; offers to delete only the ones inside a Music, Downloads, or Videos
# folder, and you pick which.

mod_media() {
    say "Media files"
    local list="$RUN_DIR/media.txt"
    find /home /root -xdev -type f -regextype posix-extended -iregex ".*\.($MEDIA_EXT)$" 2>/dev/null > "$list"
    local n
    n=$(wc -l < "$list")
    echo "    found $n media files (list in $list)"
    log INFO "media files found: $n"

    local -a work=() picked=()
    local f
    mapfile -d '' -t work < <(find /home /root -xdev -type f -regextype posix-extended -iregex ".*/($MEDIA_DIRS)/.*\.($MEDIA_EXT)$" -print0 2>/dev/null)
    if [ "${#work[@]}" -eq 0 ]; then
        echo "    no media files inside $MEDIA_DIRS folders"
        return 0
    fi
    echo "    ${#work[@]} media file(s) inside $MEDIA_DIRS folders:"
    if [ "$APPLY" -ne 1 ]; then
        printf '    %s\n' "${work[@]}"
        echo "    [dry-run] in apply mode you pick which files to delete"
        return 0
    fi
    mapfile -t picked < <(pick_numbers "Delete which of these? (numbers separated by commas, or type none)" "${work[@]}")
    for f in "${picked[@]}"; do
        [ -n "$f" ] || continue
        act "delete $f" rm -f -- "$f"
    done
    echo "    files you did not pick are kept"
}
