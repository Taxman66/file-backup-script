#!/bin/bash

usage() {
    echo "Uso: $0 dir_trabalho dir_backup"
    exit 1
}

if [ "$#" -ne 2 ]; then
    usage
fi

DIR_TRABALHO=$1
DIR_BACKUP=$2

if [ ! -d "$DIR_TRABALHO" ]; then
    echo "Erro: O Diretório de trabalho '$DIR_TRABALHO' não existe."
    exit 1
fi

if [ ! -d "$DIR_BACKUP" ]; then
    echo "Erro: O Diretório de backup '$DIR_BACKUP' não existe."
    exit 1
fi

check_files() {
    local src_dir="$1"
    local dest_dir="$2"

    for file in "$src_dir"/*; do
        local filename=$(basename "$file")
        local dest_file="$dest_dir/$filename"

        if [ -d "$file" ]; then
            if [ ! -d "$dest_file" ]; then
                echo "Erro: Diretório $dest_file não existe no backup"
            else
                check_files "$file" "$dest_file"
            fi
        elif [ -f "$file" ]; then
            if [ ! -f "$dest_file" ]; then
                echo "Erro: Arquivo $dest_file não existe no backup"
            else
                local src_hash=$(md5sum "$file" | cut -d ' ' -f 1)
                local dest_hash=$(md5sum "$dest_file" | cut -d ' ' -f 1)

                if [ "$src_hash" != "$dest_hash" ]; then
                    echo "Diferença: $file e $dest_file diferem"
                fi
            fi
        fi
    done
}

check_files "$DIR_TRABALHO" "$DIR_BACKUP"
echo "Verificação concluída."

