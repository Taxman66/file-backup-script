#!/bin/bash

working_directory="$1"
backup_directory="$2"

if ! test -d "$working_directory"; then
	echo "Working directory not found. Exiting."
        exit 1
fi

if ! test -d "$backup_directory"; then
	mkdir "$backup_directory"
fi

for FILE in "$working_directory"; do 
	cp -r "$FILE" "$backup_directory"
done

