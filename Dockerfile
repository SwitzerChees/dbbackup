
FROM ubuntu:22.04

ARG TARGETARCH

# Install pg_dump for PostgreSQL 16
RUN apt-get update && apt-get install -y wget gnupg2 lsb-release && \
    echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | tee /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
    apt-get update && \
    apt-get install -y postgresql-client-16

# Install mongodb-tools 100.9.4
RUN apt-get update && apt-get install curl -y && \
    if [ "$TARGETARCH" = "amd64" ]; then \
        curl https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2204-x86_64-100.9.4.deb --output mongodb-database-tools.deb; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        curl https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2204-arm64-100.9.4.deb --output mongodb-database-tools.deb; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; \
        exit 1; \
    fi && \
    dpkg -i mongodb-database-tools.deb && \
    rm mongodb-database-tools.deb

WORKDIR /backup

# Copy the backup script
COPY backup.sh backup.sh

# Make the backup script executable
RUN chmod +x backup.sh

# Run the backup script
CMD ["./backup.sh"]