#!/bin/bash
set -euxo pipefail

# Get version from command line argument
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Error: Version argument not provided"
    exit 1
fi

# If VERSION is "latest", we need to determine the actual version from the downloaded file
if [ "$VERSION" = "latest" ]; then
    VERSION=$(ls dist/postgres/postgresql-*.jar | sed -n 's/.*postgresql-\([0-9.]\+\)\.jar/\1/p' || true)
    if [ -z "$VERSION" ]; then
        echo "Error: Could not determine version from downloaded file" >&2
        exit 1
    fi
fi

# Create JDBC directory if it doesn't exist
JDBC_DIR="/opt/tableau/tableau_driver/jdbc"
mkdir -p "$JDBC_DIR"

# Copy the JAR file to the JDBC directory
echo "Installing PostgreSQL JDBC driver version ${VERSION}..."
if cp "dist/postgres/postgresql-${VERSION}.jar" "$JDBC_DIR/"; then
    echo "Successfully installed PostgreSQL JDBC driver to $JDBC_DIR/"
else
    echo "Error: Failed to install PostgreSQL JDBC driver" >&2
    exit 1
fi

# Clean up downloaded files
rm -f "dist/postgres/postgresql-${VERSION}.jar"