#!/bin/bash
# Database Migration Script
# Migrates on-premise database to cloud (AWS RDS / GCP Cloud SQL)

set -e

# Configuration
SOURCE_HOST="${SOURCE_HOST:-localhost}"
SOURCE_PORT="${SOURCE_PORT:-3306}"
SOURCE_DB="${SOURCE_DB:-app_db}"
SOURCE_USER="${SOURCE_USER:-root}"
SOURCE_PASS="${SOURCE_PASS:-}"

TARGET_HOST="${TARGET_HOST:-}"
TARGET_PORT="${TARGET_PORT:-3306}"
TARGET_DB="${TARGET_DB:-app_db}"
TARGET_USER="${TARGET_USER:-admin}"
TARGET_PASS="${TARGET_PASS:-}"

BACKUP_DIR="${BACKUP_DIR:-./backups}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Database Migration Script ===${NC}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Function to backup source database
backup_source() {
    echo -e "${YELLOW}Backing up source database...${NC}"
    mysqldump -h "$SOURCE_HOST" -P "$SOURCE_PORT" -u "$SOURCE_USER" \
        -p"$SOURCE_PASS" "$SOURCE_DB" > "$BACKUP_DIR/${SOURCE_DB}_$(date +%Y%m%d_%H%M%S).sql"
    echo -e "${GREEN}Backup completed${NC}"
}

# Function to restore to target
restore_target() {
    if [ -z "$TARGET_HOST" ]; then
        echo -e "${RED}TARGET_HOST not set${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Restoring to target database...${NC}"
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/*.sql | head -1)
    
    mysql -h "$TARGET_HOST" -P "$TARGET_PORT" -u "$TARGET_USER" \
        -p"$TARGET_PASS" "$TARGET_DB" < "$LATEST_BACKUP"
    echo -e "${GREEN}Restore completed${NC}"
}

# Function to verify migration
verify_migration() {
    echo -e "${YELLOW}Verifying migration...${NC}"
    
    SOURCE_COUNT=$(mysql -h "$SOURCE_HOST" -P "$SOURCE_PORT" -u "$SOURCE_USER" \
        -p"$SOURCE_PASS" -e "SELECT COUNT(*) FROM $SOURCE_DB.information_schema.tables" -s -N)
    
    TARGET_COUNT=$(mysql -h "$TARGET_HOST" -P "$TARGET_PORT" -u "$TARGET_USER" \
        -p"$TARGET_PASS" -e "SELECT COUNT(*) FROM $TARGET_DB.information_schema.tables" -s -N)
    
    if [ "$SOURCE_COUNT" -eq "$TARGET_COUNT" ]; then
        echo -e "${GREEN}Migration verified successfully${NC}"
    else
        echo -e "${RED}Migration verification failed${NC}"
        exit 1
    fi
}

# Main execution
main() {
    backup_source
    restore_target
    verify_migration
    echo -e "${GREEN}Migration completed successfully!${NC}"
}

main

