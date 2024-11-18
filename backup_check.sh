#!/bin/bash

working_directory="$1"
backup_directory="$2"

usage() {
    echo "Usage: $0 working_diretory backup_directory"
    exit 1
}

if [ "$#" -ne 2 ]; then
    usage
fi

if [ ! -d "$working_directory" ]; then
    echo "Error: The working directory '$working_directory' doesn't exist."
    exit 1
fi

if [ ! -d "$backup_directory" ]; then
    echo "Error: The backup directory '$backup_directory' doesn't exist."
    exit 1
fi
    for file in "$working_directory"/*; do
        filename=$(basename "$file")
        backup_file="$backup_directory/$filename"

        if [ -d "$file" ]; then
            if [ ! -d "$backup_file" ]; then
                echo "Error: The directory $backup_file doesn't exist in the backup directory."
            else
                ./$0 "$file" "$backup_file"
            fi
        elif [ -f "$file" ]; then
            if [ ! -f "$backup_file" ]; then
                echo "Error: The file $backup_file doesn't exist in the backup directory."
            else
                src_hash=$(md5sum "$file" | cut -d ' ' -f 1)
                dest_hash=$(md5sum "$backup_file" | cut -d ' ' -f 1)

                if [ "$src_hash" != "$dest_hash" ]; then
                    echo "Warning: $file and $backup_file are different."
                fi
            fi
        fi
    done

echo "Verification done for $working_directory."

