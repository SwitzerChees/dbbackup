#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Source the .env file
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | awk '/=/ {print $1}')
fi

# Set default values

: ${BACKUP_NAME:='my-backup'}
: ${BACKUP_DRIVER:='postgres'}
: ${BACKUP_DATABASE:='db'}
: ${BACKUP_DIR:='./backups'}
: ${BACKUP_PASSWORD:='supersecret123'}
: ${BACKUP_RETENTION:='7'}

: ${CONNECTION_HOST:='localhost'}
: ${CONNECTION_PORT:='6432'}
: ${CONNECTION_USER:='postgres'}
: ${CONNECTION_PASSWORD:='test123'}
: ${CONNECTION_AUTH_DB:='admin'}

: ${WEBDAV_URL:='https://webdav.yourdomain.com'}
: ${WEBDAV_USER:='user'}
: ${WEBDAV_PASSWORD:='password'}
: ${WEBDAV_PATH:='backup/db'}

: ${PINGCHECK_URL:='https://pingcheck.com/ping/backup/123456'}

echo "Backup driver: $BACKUP_DRIVER"

if [ ! -d $BACKUP_DIR ]; then
  mkdir -p $BACKUP_DIR
fi

timestamp=$(date +%Y%m%d%H%M%S)

# Backup postgres database
if [ "$BACKUP_DRIVER" = "postgres" ]; then
    echo "Backing up $BACKUP_DATABASE..."
    backup_file=$BACKUP_DATABASE-$timestamp.dump
    backup_path=$BACKUP_DIR/$backup_file
    PGPASSWORD=$CONNECTION_PASSWORD pg_dump -h $CONNECTION_HOST -p $CONNECTION_PORT -U $CONNECTION_USER $BACKUP_DATABASE -Fc -f $backup_path
    echo "Backup saved to $backup_path"
    echo "Compressing backup file..."
    tar -czf $backup_path.tar.gz -C $BACKUP_DIR $backup_file
    rm $backup_path
    backup_path=$backup_path.tar.gz
# Backup mongodb database
elif [ "$BACKUP_DRIVER" = "mongodb" ]; then
    echo "Backing up $BACKUP_NAME..."
    backup_path=$BACKUP_DIR/$BACKUP_NAME-$timestamp.tar.gz
    mongodump --host $CONNECTION_HOST --port $CONNECTION_PORT --username $CONNECTION_USER --password $CONNECTION_PASSWORD --archive=$backup_path --authenticationDatabase $CONNECTION_AUTH_DB --gzip
    echo "Backup saved to $backup_path"
else
    echo "Invalid backup driver: $BACKUP_DRIVER"
    exit 1
fi

# Encrypt backup files
echo "Encrypting backup file..."
openssl enc -aes-256-cbc -salt -in $backup_path -out $backup_path.enc -pbkdf2 -pass pass:$BACKUP_PASSWORD
rm $backup_path
echo "Backup file encrypted and saved to $backup_path.enc"

# Upload backup files to webdav
echo "Uploading backup file to webdav..."
backup_file=$(basename $backup_path)
curl -u $WEBDAV_USER:$WEBDAV_PASSWORD -T $backup_path.enc $WEBDAV_URL/$WEBDAV_PATH/$backup_file.enc
echo "Backup file uploaded to $WEBDAV_URL/$WEBDAV_PATH/$backup_file.enc"
rm $backup_path.enc

# Remove old backups on webdav based on retention policy
echo "Removing old backups..."

# Use PROPFIND to list files
file_list=$(curl -s -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -X PROPFIND "$WEBDAV_URL/$WEBDAV_PATH/" -H "Depth: 1" | \
grep -o "<d:href>[^<]*</d:href>" | sed -e 's/<[^>]*>//g' | grep -v "/$")

# Extract filenames and sort by date in the filename
sorted_files=$(echo "$file_list" | awk -F'/' '{print $NF}' | sort -t '-' -k3,3)

# Keep only the latest N files and delete the rest
files_to_keep=$(echo "$sorted_files" | tail -n "$BACKUP_RETENTION")

# Find files to delete
files_to_delete=$(comm -23 <(echo "$sorted_files" | tr ' ' '\n' | sort) <(echo "$files_to_keep" | tr ' ' '\n' | sort))

# Delete the files that are beyond the retention period
for file in $files_to_delete; do
    curl -u "$WEBDAV_USER:$WEBDAV_PASSWORD" -X DELETE "$WEBDAV_URL/$WEBDAV_PATH/$file"
    echo "Removed $WEBDAV_URL/$WEBDAV_PATH/$file"
done

# Ping check with curl if return is pong then it is successful
echo "Pinging check..."
ping_check=$(curl -s $PINGCHECK_URL)
echo "Ping check returned: $ping_check"
if [ "$ping_check" = "Pong" ]; then
    echo "Ping check successful"
elif [ "$ping_check" = "{\"ok\":true}" ]; then
    echo "Ping check successful"
else
    echo "Ping check failed"
    exit 1
fi

echo "Backup completed successfully"
exit 0
