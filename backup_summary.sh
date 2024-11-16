#!/bin/bash

usage() {
    echo "Usage: $0 [-c] [-b ignore_file] [-r regex] working_directory backup_directory"
    exit 1
}

working_directory="${@: -2:1}"
backup_directory="${@: -1:1}"

CHECK_MODE=false
IGNORE_FILE=""
REGEX=""
ERRORS=0
WARNINGS=0
UPDATED=0
COPIED=0
DELETED=0
COPIED_SIZE=0
UPDATED_SIZE=0
DELETED_SIZE=0
dir_copied=0
dir_updated=0
dir_deleted=0
dir_copied_size=0
dir_updated_size=0
dir_deleted_size=0
dir_warnings=0

while getopts ":cb:r:" opt; do
    case $opt in
        c)
            CHECK_MODE=true
            ;;
        b)
            IGNORE_FILE="$OPTARG"
            ;;
        r)
            REGEX="$OPTARG"
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
        continue
    fi

    if [ -n "$REGEX" ] && [[ ! "$(basename "$file")" =~ $REGEX ]]; then
        continue
    fi

    mod_date_working=$(stat "$file" | awk '/Modify/ { print $2, $3 }' | xargs -I{} date -d {} +%s)
    backup_file="$backup_directory/$(basename "$file")"

    if [ -d "$file" ]; then
        ./$0 "$file" "$backup_file"
    else
        file_size=$(stat -c%s "$file")
        if [ -f "$backup_file" ]; then
            mod_date_backup=$(stat "$backup_file" | awk '/Modify/ { print $2, $3 }' | xargs -I{} date -d {} +%s)
            if (( mod_date_backup > mod_date_working )); then
				echo "File in backup directory ($backup_file) is newer than corresponding file in source directory. Not copying this file."
			else
                if [ "$CHECK_MODE" = false ]; then
                    echo "Updating: $file -> $backup_file"
                    cp -a "$file" "$backup_file"
                    UPDATED=$((UPDATED + 1))
                    UPDATED_SIZE=$((UPDATED_SIZE + file_size))
                    dir_updated=$((dir_updated + 1))
                    dir_updated_size=$((dir_updated_size + file_size))
                else
                    echo "cp -a $file $backup_file"
                fi
            fi
        else
            if [ "$CHECK_MODE" = false ]; then
                echo "Copying: $file -> $backup_file"
                cp -a "$file" "$backup_file"
                COPIED=$((COPIED + 1))
                COPIED_SIZE=$((COPIED_SIZE + file_size))
                dir_copied=$((dir_copied + 1))
                dir_copied_size=$((dir_copied_size + file_size))
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
            echo "Removing: $file (it no longer exists in $working_directory)"
            rm -rf "$file"
            DELETED=$((DELETED + 1))
            DELETED_SIZE=$((DELETED_SIZE + file_size))
            dir_deleted=$((dir_deleted + 1))
            dir_deleted_size=$((dir_deleted_size + file_size))
        else
            echo "rm -rf $file"
        fi
    fi
done

echo "While backing up $working_directory: $ERRORS Errors; $dir_warnings Warnings; $dir_updated Updated; $dir_copied Copied ($dir_copied_size Bytes); $dir_deleted Deleted ($dir_deleted_size Bytes)"

