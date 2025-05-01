#!/bin/bash
set -euxo pipefail

# Get version from command line argument
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Error: Version argument not provided"
    exit 1
fi

# Output directory
DEST_DIR="dist/postgres"
mkdir -p "$DEST_DIR"

# Handle "latest" version by scraping the download page
if [ "$VERSION" = "latest" ]; then
    echo "Finding latest PostgreSQL JDBC driver version for Java 8..."
    # Download the page and extract the latest Java 8 version
    DOWNLOAD_PAGE=$(curl -sSL https://jdbc.postgresql.org/download/)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch PostgreSQL JDBC download page" >&2
        exit 1
    fi
    
    # Extract version for Java 8 driver
    # Look for pattern like: postgresql-42.7.1.jar
    VERSION=$(echo "$DOWNLOAD_PAGE" | grep -o 'postgresql-[0-9.]\+\.jar' | head -n 1 | sed 's/postgresql-\([0-9.]\+\)\.jar/\1/' || true)
    
    if [ -z "$VERSION" ]; then
        echo "Error: Could not determine latest Java 8 driver version" >&2
        exit 1
    fi
    echo "Found latest Java 8 driver version: $VERSION"
fi

# Construct download URL
DOWNLOAD_URL="https://jdbc.postgresql.org/download/postgresql-${VERSION}.jar"

# Download the JAR file
echo "Downloading PostgreSQL JDBC driver version ${VERSION}..."
if curl -sSL -f -o "$DEST_DIR/postgresql-${VERSION}.jar" "$DOWNLOAD_URL"; then
    echo "Successfully downloaded PostgreSQL JDBC driver to $DEST_DIR/postgresql-${VERSION}.jar"
else
    echo "Error: Failed to download PostgreSQL JDBC driver version ${VERSION}" >&2
    exit 1
fi