#!/bin/bash

working_directory="${@: -2:1}"
backup_directory="${@: -1:1}"

CHECK_MODE=false

OPTSTRING=":c"

usage() {
    echo "Usage: $0 [-c] working_dir backup_dir"
    exit 1
}

if [ "$#" -lt 2 ]; then
    usage
fi

while getopts ${OPTSTRING} opt; do
	case ${opt} in
	  c) 
	    CHECK_MODE=true
	    ;;
	  ?)
	    echo "Option not found"
	    exit 1
	    ;;
	esac
done

if [ ! -d "$working_directory" ]; then
    echo "Working directory not found. Exiting."
    exit 1
fi

if [[ "$backup_directory" == "$working_directory"* ]]; then
    echo "Error: The backup directory '$backup_directory' cannot be inside the working directory '$working_directory'."
    exit 1
fi

if [ ! -d "$backup_directory" ]; then
	if [ "$CHECK_MODE" = false ]; then
		echo "mkdir $backup_directory"
        mkdir "$backup_directory"
	else
		echo "CHECK MODE: mkdir $backup_directory"
	fi
fi

for file in "$working_directory"/*; do
	if [ -f "$file" ]; then
		mod_date_working=$(stat "$file" | awk '/Modify/ { print $2, $3 }' | xargs -I{} date -d {} +%s)

		backup_file="$backup_directory/$(basename "$file")"

		if [ -f "$backup_file" ]; then
			mod_date_backup=$(stat "$backup_file" | awk '/Modify/ { print $2, $3 }' | xargs -I{} date -d {} +%s)
			if (( mod_date_backup > mod_date_working )); then
				echo "File in backup directory ($backup_file) is newer than corresponding file in source directory. Not copying this file."
			else
				if [ "$CHECK_MODE" = false ]; then
					echo "cp -a $file $backup_directory"
					cp -a "$file" "$backup_directory"
				else
					echo "CHECK MODE: cp -a $file $backup_directory"
				fi
			fi
		else
			if [ "$CHECK_MODE" = false ]; then
				echo "cp -a $file $backup_directory"
        		cp -a "$file" "$backup_directory"
			else
				echo "CHECK MODE: cp -a $file $backup_directory"
			fi
		fi
	fi	
done

for file in "$backup_directory"/*; do
	working_file="$working_directory/$(basename "$file")"

	if [ -f "$file" ] && [ ! -f "$working_file" ]; then
		if [ "$CHECK_MODE" = false ]; then
			echo "rm -f $file"
			rm -f "$file"
		else
			echo "CHECK MODE: rm -f $file"
		fi
	fi
done
