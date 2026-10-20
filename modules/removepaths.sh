# shellcheck shell=bash
# Folders in user Desktop, Documents, Downloads, Music, Videos, and Pictures. You pick which ones to delete.

mod_removepaths() {
    say "Folders to clear: folders in user home folders"
    local -a candidates=()
    local d
    while IFS= read -r d; do
        case "$d" in *cp-toolkit*|*/cp-reports*|*CyberPatriot*) continue ;; esac
        candidates+=("$d")
    done < <(find /home/*/Desktop /home/*/Documents /home/*/Downloads /home/*/Music /home/*/Videos /home/*/Pictures \
        -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

    if [ "${#candidates[@]}" -eq 0 ]; then
        echo "    no folders found in the user home folders"
        return 0
    fi
    local -a labels=()
    local count
    for d in "${candidates[@]}"; do
        count=$(find "$d" -type f 2>/dev/null | wc -l)
        labels+=("$d  ($count files)")
    done
    echo "    ${#candidates[@]} folder(s). Check each one before removing. Removing a required folder can cost points."

    if [ "$APPLY" -ne 1 ]; then
        printf '    %s\n' "${labels[@]}"
        echo "    [dry-run] in apply mode you pick which folders to delete"
        return 0
    fi
    local -a picked=()
    mapfile -t picked < <(pick_numbers "Delete which of these folders? (numbers separated by commas, or type none)" "${labels[@]}")
    local label folder
    for label in "${picked[@]}"; do
        [ -n "$label" ] || continue
        folder=${label%  (*files)}
        # Only folders inside a user's home folder can be removed here.
        case "$folder" in
            /home/*/*) ;;
            *) echo "    skipped (not inside a home folder): $folder"; continue ;;
        esac
        act "delete folder $folder" rm -rf -- "$folder"
    done
    echo "    folders you did not pick are kept"
}
