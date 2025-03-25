#!/bin/bash
# Database credentials
DB_USER="user"
DB_PASSWORD="password"
DB_NAME="your_database_name" # You should replace this with your actual database name

# Database dump file
DB_DUMP_FILE="/path/to/your/backup_dump.sql"

# Drop existing and create new database
mariadb -u"$DB_USER" -p"$DB_PASSWORD" -e "DROP DATABASE IF EXISTS $DB_NAME; CREATE DATABASE $DB_NAME;"

# Import the database
if mariadb -u"$DB_USER" -p"$DB_PASSWORD" $DB_NAME < "$DB_DUMP_FILE"; then
    echo "$(date) - Database import successful."
else
    echo "$(date) - ERROR: Database import failed!"
fi