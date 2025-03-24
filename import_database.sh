#!/bin/bash

# Database credentials
DB_USER="user"
DB_PASSWORD="password"

# Database dump file
DB_DUMP_FILE="/path/to/your/backup_dump.sql"

# Import the databases
if mysql -u"$DB_USER" -p"$DB_PASSWORD" < "$DB_DUMP_FILE"; then
    echo "$(date) - Database import successful."
else
    echo "$(date) - ERROR: Database import failed!"
fi