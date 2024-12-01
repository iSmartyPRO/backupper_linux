#!/bin/bash

# Check for --config parameter
if [[ "$1" != "--config" || -z "$2" ]]; then
  echo "Usage: $0 --config <path_to_config_file>"
  exit 1
fi

CONFIG_FILE="$2"

# Check if the configuration file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Read the configuration file
CONFIG=$(jq '.' "$CONFIG_FILE")
if [[ $? -ne 0 ]]; then
  echo "Error reading configuration file"
  exit 1
fi

NAME=$(echo "$CONFIG" | jq -r '.name')
BACKUP_FOLDER=$(echo "$CONFIG" | jq -r '.backup2folder')
LOG_FOLDER=$(echo "$CONFIG" | jq -r '.log2folder')
BACKUP_DAYS=$(echo "$CONFIG" | jq -r '.backupDays')

# Format timestamps
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")
BACKUP_FILE="${BACKUP_FOLDER}/${NAME}_${TIMESTAMP}.tar.gz"
LOG_FILE="${LOG_FOLDER}/${NAME}_${TIMESTAMP}.log"
STATUS_FILE="${BACKUP_FOLDER}/${NAME}_status.log"

# Initialize overall status flag
GLOBAL_STATUS="OK"

log() {
  /bin/echo "$(/bin/date +'%Y-%m-%d %H:%M:%S') $1" | /usr/bin/tee -a "$LOG_FILE"
}

log "Backup process started"

START_TIME=$(date +%s)

# Delete old backups
log "Deleting backups older than $BACKUP_DAYS days"
find "$BACKUP_FOLDER" -type f -name "*.tar.gz" -mtime +$BACKUP_DAYS -exec rm -f {} \;

TEMP_DIR=$(mktemp -d)

# Function to check the status of the last command
check_status() {
  if [[ $? -ne 0 ]]; then
    GLOBAL_STATUS="Bad"
  fi
}

# Backup MariaDB databases
backup_mariadb() {
  DB=$1
  NAME=$(echo "$DB" | jq -r '.name')
  ENABLED=$(echo "$DB" | jq -r '.enabled')
  if [[ "$ENABLED" == "true" ]]; then
    log "Backing up MariaDB: $NAME"
    HOST=$(echo "$DB" | jq -r '.host')
    PORT=$(echo "$DB" | jq -r '.port')
    DBNAME=$(echo "$DB" | jq -r '.dbname')
    DBUSER=$(echo "$DB" | jq -r '.dbuser')
    DBPASS=$(echo "$DB" | jq -r '.dbpass')
    mysqldump -h "$HOST" -P "$PORT" -u "$DBUSER" -p"$DBPASS" "$DBNAME" > "$TEMP_DIR/${NAME}.sql"
    check_status
    if [[ "$GLOBAL_STATUS" == "Bad" ]]; then
      log "Error backing up MariaDB: $NAME"
    else
      mkdir -p "$TEMP_DIR/$NAME"
      mv "$TEMP_DIR/${NAME}.sql" "$TEMP_DIR/$NAME/"
    fi
  fi
}

# Backup MongoDB databases
backup_mongodb() {
  DB=$1
  NAME=$(echo "$DB" | jq -r '.name')
  ENABLED=$(echo "$DB" | jq -r '.enabled')
  if [[ "$ENABLED" == "true" ]]; then
    log "Backing up MongoDB: $NAME"
    HOST=$(echo "$DB" | jq -r '.host')
    PORT=$(echo "$DB" | jq -r '.port')
    DBNAME=$(echo "$DB" | jq -r '.dbname')
    DBUSER=$(echo "$DB" | jq -r '.dbuser')
    DBPASS=$(echo "$DB" | jq -r '.dbpass')
    mongodump --host "$HOST" --port "$PORT" --username "$DBUSER" --password "$DBPASS" --db "$DBNAME" --out "$TEMP_DIR/mongodb_$NAME"
    check_status
    if [[ "$GLOBAL_STATUS" == "Bad" ]]; then
      log "Error backing up MongoDB: $NAME"
    fi
  fi
}

# Backup folders
backup_folder() {
  FOLDER=$1
  NAME=$(/usr/bin/jq -r '.name' <<< "$FOLDER")
  ENABLED=$(/usr/bin/jq -r '.enabled' <<< "$FOLDER")
  if [[ "$ENABLED" == "true" ]]; then
    PATH=$(/usr/bin/jq -r '.path' <<< "$FOLDER")
    log "Backing up folder: $NAME"
    /bin/mkdir -p "$TEMP_DIR/$NAME"
    /bin/cp -r "$PATH"/* "$TEMP_DIR/$NAME/"
    check_status
    if [[ "$GLOBAL_STATUS" == "Bad" ]]; then
      log "Error backing up folder: $NAME"
    fi
  fi
}

# Backup all components
echo "$CONFIG" | jq -c '.mariadb[]' | while read -r DB; do
  backup_mariadb "$DB"
done

echo "$CONFIG" | jq -c '.mongodb[]' | while read -r DB; do
  backup_mongodb "$DB"
done

echo "$CONFIG" | jq -c '.folders[]' | while read -r FOLDER; do
  backup_folder "$FOLDER"
done

# Archive the backup
log "Creating archive $BACKUP_FILE"
tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" .
check_status
if [[ "$GLOBAL_STATUS" == "Bad" ]]; then
  log "Error creating archive"
fi

# Clean up temporary files
rm -rf "$TEMP_DIR"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Write final status to status file
echo "$GLOBAL_STATUS" > "$STATUS_FILE"
log "Backup process completed"
log "Backup started at: $(date -d @$START_TIME +'%Y-%m-%d %H:%M:%S')"
log "Backup ended at: $(date -d @$END_TIME +'%Y-%m-%d %H:%M:%S')"
log "Backup duration: $((DURATION / 60)) minutes and $((DURATION % 60)) seconds"
log "Overall status: $GLOBAL_STATUS"
