#!/bin/bash
set -e  # Exit immediately on errors outside conditionals

# ========== CONFIG SECTION ==========
BACKUP_HOST="ubuntu@99.46.81.50"    # Backup server username@hostname or IP
SOURCE_DIR="/home/ubuntu"           # Local path to folders
SERVICES=("velocity" "mc1" "mc2" "mc3")  # Systemd services
FOLDERS=("velocity" "mc1" "mc2" "mc3")    # Folders to sync
BACKUP_DIR="/home/ubuntu/backups"   # Folder to store database dumps
DB_DUMP_FILE="$BACKUP_DIR/mariadb_backup.sql"  # Database dump file
SSH_KEY="/home/ubuntu/.ssh/sooknu-cloud.key"     # Private SSH key
TMP_DIR="/tmp/systemd_backup"       # Temporary storage for systemd files
LOG_FILE="/home/ubuntu/backup_mirror.log"  # Log file location

# Database credentials (update with your actual credentials)
DB_USER="sahid"          
DB_PASSWORD="NX6ri4p5!"
DB_HOST="localhost"
DB_DUMP_CMD="/usr/bin/mariadb-dump"  # Recommended dump command

# ========== ENABLE/DISABLE FEATURES ==========
ENABLE_FOLDERS=true    
ENABLE_SERVICES=true   
ENABLE_DATABASE=true   
# =============================================

# Redirect output to log file
exec > >(tee -a "$LOG_FILE") 2>&1

echo "====================================================="
echo "$(date) - Starting backup to $BACKUP_HOST..."
echo "====================================================="

# ========== DEPENDENCY CHECKS ==========
required_cmds=("rsync" "ssh" "$DB_DUMP_CMD")
for cmd in "${required_cmds[@]}"; do
    if ! command -v ${cmd##*/} >/dev/null 2>&1; then
        echo "$(date) - ERROR: Required command '$cmd' is not installed. Aborting."
        exit 1
    fi
done

if [ ! -f "$SSH_KEY" ]; then
    echo "$(date) - ERROR: SSH key $SSH_KEY not found. Aborting."
    exit 1
fi

# ========== FUNCTIONS ==========
sync_files() {
    local src="$1"
    local dst="$2"
    local opts="$3"
    # Using -az with --stats for summary info; omit -v for quieter output.
    if ! rsync -az --stats $opts -e "ssh -i ${SSH_KEY}" "$src" "$dst"; then
        echo "$(date) - ERROR: Failed to sync $src to $dst"
    fi
}

# ========== MINECRAFT FOLDER BACKUP ==========
if [ "$ENABLE_FOLDERS" = true ]; then
    echo "$(date) - Syncing Minecraft folders..."
    for DIR in "${FOLDERS[@]}"; do
        LOCAL_PATH="${SOURCE_DIR}/${DIR}"
        REMOTE_PATH="${BACKUP_HOST}:${SOURCE_DIR}/${DIR}"
        if [ -d "$LOCAL_PATH" ]; then
            sync_files "$LOCAL_PATH/" "$REMOTE_PATH/" "--delete"
            echo "$(date) - Synced folder: $DIR"
        else
            echo "$(date) - Skipping non-existent folder: $DIR"
        fi
    done
else
    echo "$(date) - Minecraft folder backup is DISABLED."
fi

# ========== SYSTEMD SERVICE BACKUP ==========
if [ "$ENABLE_SERVICES" = true ]; then
    echo "$(date) - Syncing systemd service files..."
    ssh -i "$SSH_KEY" "$BACKUP_HOST" "mkdir -p $TMP_DIR && sudo mkdir -p /etc/systemd/system/"
    for SERVICE in "${SERVICES[@]}"; do
        LOCAL_SERVICE_FILE="/etc/systemd/system/${SERVICE}.service"
        REMOTE_TEMP_FILE="${BACKUP_HOST}:${TMP_DIR}/${SERVICE}.service"
        if [ -f "$LOCAL_SERVICE_FILE" ]; then
            sync_files "$LOCAL_SERVICE_FILE" "$REMOTE_TEMP_FILE"
            ssh -i "$SSH_KEY" "$BACKUP_HOST" "sudo mv $TMP_DIR/${SERVICE}.service /etc/systemd/system/"
            echo "$(date) - Synced service: ${SERVICE}.service"
        else
            echo "$(date) - Skipping missing service file: ${SERVICE}.service"
        fi
    done
    ssh -i "$SSH_KEY" "$BACKUP_HOST" "sudo systemctl daemon-reload"
else
    echo "$(date) - Systemd service backup is DISABLED."
fi

# ========== DATABASE DUMP ==========
if [ "$ENABLE_DATABASE" = true ]; then
    echo "$(date) - Dumping MariaDB databases..."
    mkdir -p "$BACKUP_DIR"
    if "$DB_DUMP_CMD" --user="$DB_USER" --password="$DB_PASSWORD" --host="$DB_HOST" \
         --all-databases --single-transaction --quick --lock-tables=false > "$DB_DUMP_FILE"; then
        echo "$(date) - Database dump successful."
        sync_files "$BACKUP_DIR/" "$BACKUP_HOST:$BACKUP_DIR/"
        echo "$(date) - Database backup synced."
    else
        echo "$(date) - ERROR: MariaDB backup failed!"
    fi
else
    echo "$(date) - MariaDB backup is DISABLED."
fi

echo "$(date) - Backup complete!"
echo "====================================================="
