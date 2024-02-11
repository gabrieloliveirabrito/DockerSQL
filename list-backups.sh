#!/bin/bash

# Caminho para a pasta de backup
backup_path="./Backup"

# Inicializar a variável SQL
sql_query="INSERT INTO @Files (BackupFile) VALUES "

# Loop através dos arquivos .bak no diretório de backup
for backup_file in "$backup_path"/*.bak; do
    # Extrair o nome do arquivo sem o caminho
    filename=$(basename "$backup_file")
    
    # Adicionar o nome do arquivo à consulta SQL
    sql_query+="('/var/opt/mssql/backup/$filename'),"
done

# Remover a vírgula extra no final da consulta SQL
sql_query="${sql_query%,}"

# Imprimir a consulta SQL final
echo "$sql_query"
