#!/bin/bash

working_directory="${@: -2:1}"
backup_directory="${@: -1:1}"

CHECK_MODE=false
RECURSIVE_OPTIONS=()

IGNORE_FILE=""
REGEX=""
ERRORS=0
WARNINGS=0
UPDATED=0
COPIED=0
DELETED=0
COPIED_SIZE=0
DELETED_SIZE=0
OPTSTRING=":cb:r:"

usage() {
    echo "Usage: $0 [-c] [-b ignore_file] [-r regex] working_directory backup_directory"
    exit 1
}

if [ "$#" -lt 2 ]; then
    usage
fi

while getopts ${OPTSTRING} opt; do
    case $opt in
        c)
            CHECK_MODE=true
            RECURSIVE_OPTIONS+=("-c")
            ;;
        b)
            IGNORE_FILE="$OPTARG"
            RECURSIVE_OPTIONS+=("-b" "$OPTARG")
            ;;
        r)
            REGEX="$OPTARG"
            RECURSIVE_OPTIONS+=("-r" "$OPTARG")
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done

if [ ! -d "$working_directory" ]; then
    echo "Error: The working directory '$working_directory' doesn't exist."
    exit 1
fi

if [[ "$backup_directory" == "$working_directory"* ]]; then
    echo "Error: The backup directory '$backup_directory' cannot be inside the working directory '$working_directory'."
    exit 1
fi

if [ ! -d "$backup_directory" ]; then
    if [ "$CHECK_MODE" = false ]; then
        echo "Creating backup directory: $backup_directory"
        echo "mkdir -p $backup_directory"
        mkdir -p "$backup_directory"
    else
        echo "mkdir -p $backup_directory"
    fi
fi

should_ignore() {
    local file=$1
    if [ -n "$IGNORE_FILE" ] && grep -q "^$file$" "$IGNORE_FILE"; then
        return 0
    fi
    return 1
}

for file in "$working_directory"/*; do
    if should_ignore "$(basename "$file")"; then
        echo "File $file is in the list of files/directories not to be copied. Not copying this file."
        continue
    fi

    if [ -n "$REGEX" ] && [[ ! "$(basename "$file")" =~ $REGEX ]]; then
        echo "File $file doesn't match the provided REGEX. Not copying this file."
        continue
    fi

    backup_file="$backup_directory/$(basename "$file")"

    if [ -d "$file" ]; then
        ./$0 "${RECURSIVE_OPTIONS[@]}" "$file" "$backup_file"
    else
        file_size=$(stat -c%s "$file")
        if [ -f "$backup_file" ]; then
            mod_date_working=$(stat "$file" | awk '/Modify/ { print $2, $3 }' | xargs -I{} date -d {} +%s)
            mod_date_backup=$(stat "$backup_file" | awk '/Modify/ { print $2, $3 }' | xargs -I{} date -d {} +%s)
            if (( mod_date_backup > mod_date_working )); then
				echo "File in backup directory ($backup_file) is newer than corresponding file in source directory. Not copying this file."
                WARNINGS=$((WARNINGS + 1))
            elif (( mod_date_backup == mod_date_working )); then
                echo "File in backup directory ($backup_file) was modified at the same time as corresponding file in source directory. Not copying this file." 
            else
                if [ "$CHECK_MODE" = false ]; then
                    echo "cp -a $file $backup_file"
                    cp -a "$file" "$backup_file"
                    UPDATED=$((UPDATED + 1))
                else
                    echo "cp -a $file $backup_file"
                fi
            fi
        else
            if [ "$CHECK_MODE" = false ]; then
                echo "cp -a $file $backup_file"
                cp -a "$file" "$backup_file"
                COPIED=$((COPIED + 1))
                COPIED_SIZE=$((COPIED_SIZE + file_size))
            else
                echo "cp -a $file $backup_file"
            fi
        fi
    fi
done

for file in "$backup_directory"/*; do
    working_file="$working_directory/$(basename "$file")"
    if [ ! -e "$working_file" ]; then
        file_size=$(stat -c%s "$file" 2>/dev/null || echo 0)
        if [ "$CHECK_MODE" = false ]; then
            echo "rm -rf $file (file no longer exists in $working_directory)"
            rm -rf "$file"
            DELETED=$((DELETED + 1))
            DELETED_SIZE=$((DELETED_SIZE + file_size))
        else
            echo "rm -rf $file"
        fi
    fi
done

if [ "$CHECK_MODE" = false ]; then
    echo "While backuping $working_directory: $ERRORS Errors; $WARNINGS Warnings; $UPDATED Updated; $COPIED Copied ($COPIED_SIZE Bytes); $DELETED Deleted ($DELETED_SIZE Bytes)"
fi