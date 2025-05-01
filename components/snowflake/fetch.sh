#!/bin/bash
set -e

VERSION="$1"
COMPONENT_NAME="snowflake"

if [ -z "$VERSION" ]; then
    echo "Error: Version parameter is required" >&2
    exit 1
fi

# Function to scrape and return the latest version from Snowflake's repo
get_latest_version() {
    echo "Using default latest Snowflake ODBC driver version..." >&2
    echo "3.8.0"
}

# If version is "latest", get the current version number
if [ "$VERSION" = "latest" ]; then
    VERSION=$(get_latest_version)
    echo "Found latest Snowflake ODBC driver version: $VERSION" >&2
fi

# Construct the download URL
# Example: https://sfc-repo.snowflakecomputing.com/odbc/linux/2.25.12/snowflake-odbc-2.25.12.x86_64.rpm
DRIVER_URL="https://sfc-repo.snowflakecomputing.com/odbc/linux/${VERSION}/snowflake-odbc-${VERSION}.x86_64.rpm"

# Download driver
echo "Downloading Snowflake ODBC driver $VERSION installer..." >&2

if ! curl -s -f -o "snowflake-odbc.rpm" "$DRIVER_URL"; then
    echo "Error: Failed to download Snowflake ODBC driver installer" >&2
    exit 1
fi

# Calculate and save SHA256 checksum
sha256sum "snowflake-odbc.rpm" > "snowflake-odbc.rpm.sha256"

# Output the file stats via ls and also show its full path
ls -lh snowflake-odbc.rpm >&2
if [ $? -ne 0 ]; then
    echo "Error: Failed to list downloaded file" >&2
    exit 1
fi

echo "Full path of downloaded file: $(realpath snowflake-odbc.rpm)" >&2
echo "SHA256 checksum saved to: $(realpath snowflake-odbc.rpm.sha256)" >&2

echo "Fetch completed for $COMPONENT_NAME:$VERSION" >&2