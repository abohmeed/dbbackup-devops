#!/usr/bin/env bats

# Configuration for testing
BACKUP_DIR="backups"
DB_NAME="mydatabase"

# Test 1: Check if backup directory exists
@test "Backup directory exists" {
  run bash -c "[ -d \"$BACKUP_DIR\" ]"
  [ "$status" -eq 0 ]
}

# Test 2: Check if backup file is created and non-empty
@test "Backup file is created and is non-empty" {
  run bash ./backup.sh
  BACKUP_FILE=$output
  [ "$status" -eq 0 ] && [ -f $BACKUP_FILE ] && [ "$(wc -c < $BACKUP_FILE)" -gt 0 ]
}
