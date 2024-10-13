#!/bin/bash

# Load environment variables from .env file
set -a
[ -f .env ] && . .env
set +a

# Configuration
BACKUP_DIR="backups"
TIMESTAMP=$(date +"%F_%T")

# Check if backup directory exists, if not create it
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
fi

# Perform the backup
mysqldump -h "$DB_HOST" -u "$DB_USER" "$DB_NAME" > "$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"

# Check if the backup was successful
if [ $? -eq 0 ]; then
    echo "$BACKUP_DIR/${DB_NAME}_backup_$TIMESTAMP.sql"
else
    echo "Backup failed!"
    exit 1
fi

