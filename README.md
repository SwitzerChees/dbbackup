## Build Docker Image

```bash
docker buildx build --push --platform=linux/amd64,linux/arm64 -t switzerchees/dbbackup:1.0.0 .
```

## Restore PostgreSQL Backup

```bash

# ⚠️ Without .tar.gz.enc extension
backup_file="dbbackup.dump"

# Decrypt backup file
openssl enc -d -aes-256-cbc -salt -in "$backup_file.tar.gz.enc" -out "$backup_file.tar.gz" -pbkdf2

# Extract backup file
tar -xzf "$backup_file.tar.gz" -C .

# Create database
# ⚠️ The database name must only contain lowercase letters, numbers, and underscores
psql -U postgres -h localhost -p 6432 -c "CREATE DATABASE restoreddb"

# Restore database
pg_restore -U postgres -d restoreddb -h localhost -p 6432 -v "$backup_file"
```

## Restore MongoDB Backup

```bash

# ⚠️ Without .enc extension
backup_file="dbbackup.tar.gz"

# Decrypt backup file
openssl enc -d -aes-256-cbc -salt -in "$backup_file.enc" -out "$backup_file" -pbkdf2

# Restore database
mongorestore --archive="$backup_file" --gzip --username root --authenticationDatabase admin
```
