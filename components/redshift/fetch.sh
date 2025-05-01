#!/bin/bash
set -e

VERSION="$1"
COMPONENT_NAME="redshift"

if [ -z "$VERSION" ]; then
    echo "Error: Version parameter is required" >&2
    exit 1
fi

# Function to scrape and return the latest version from the RPM link
get_latest_version() {
    echo "Fetching latest Redshift ODBC driver version..." >&2
    # Look for the 64-bit RPM download link and extract the full version number
    VERSION=$(curl -s "https://docs.aws.amazon.com/redshift/latest/mgmt/odbc-driver-linux-how-to-install.html" | \
              grep -o 's3\.amazonaws\.com/redshift-downloads/drivers/odbc/[0-9.]\+/AmazonRedshiftODBC-64-bit-[0-9.]\+-1\.x86_64\.rpm' | \
              head -1 | \
              sed -E 's|.*drivers/odbc/([0-9.]+)/.*|\1|')

    if [ -z "$VERSION" ]; then
        echo "Error: Could not find latest Redshift ODBC driver version from RPM link" >&2
        exit 1
    fi
    echo "$VERSION"
}

# If version is "latest", get the current version number
if [ "$VERSION" = "latest" ]; then
    VERSION=$(get_latest_version)
    echo "Found latest Redshift ODBC driver version: $VERSION" >&2
fi

# Construct the download URL
# Example: https://s3.amazonaws.com/redshift-downloads/drivers/odbc/1.5.20.1024/AmazonRedshiftODBC-64-bit-1.5.20.1024-1.x86_64.rpm
DRIVER_URL="https://s3.amazonaws.com/redshift-downloads/drivers/odbc/${VERSION}/AmazonRedshiftODBC-64-bit-${VERSION}-1.x86_64.rpm"

# Download driver
echo "Downloading Redshift ODBC driver $VERSION installer..." >&2
DRIVER_URL="https://s3.amazonaws.com/redshift-downloads/drivers/odbc/${VERSION}/AmazonRedshiftODBC-64-bit-${VERSION}-1.x86_64.rpm"

if ! curl -s -f -o "redshift-odbc.rpm" "$DRIVER_URL"; then
    echo "Error: Failed to download Redshift ODBC driver installer" >&2
    exit 1
fi

# output the file stats via ls and also show its full path
ls -lh redshift-odbc.rpm >&2
if [ $? -ne 0 ]; then
    echo "Error: Failed to list downloaded file" >&2
    exit 1
fi

echo "Full path of downloaded file: $(realpath redshift-odbc.rpm)" >&2

echo "Fetch completed for $COMPONENT_NAME:$VERSION" >&2