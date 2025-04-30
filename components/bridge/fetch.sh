#!/bin/bash
set -e

VERSION="$1"
COMPONENT_NAME="bridge"

if [ -z "$VERSION" ]; then
    echo "Error: Version parameter is required" >&2
    exit 1
fi

# If version is "latest", scrape the latest version number
if [ "$VERSION" = "latest" ]; then
    echo "Fetching latest Tableau Bridge version..." >&2
    BRIDGE_PAGE=$(curl -s "https://www.tableau.com/support/releases/bridge/latest")
    VERSION=$(echo "$BRIDGE_PAGE" | grep -o '[0-9]\{5\}\.[0-9]\{2\}\.[0-9]\{4\}\.[0-9]\{4\}' | head -1)

    if [ -z "$VERSION" ]; then
        echo "Error: Could not find latest Bridge version number" >&2
        exit 1
    fi
    echo "Found latest Bridge version: $VERSION" >&2
fi

# Validate version format
if ! [[ $VERSION =~ ^[0-9]{4}[0-9]\.[0-9]{2}\.[0-9]{4}\.[0-9]{4}$ ]]; then
    echo "Error: Invalid version format. Expected: YYYYN.YY.MMDD.HHMM" >&2
    exit 1
fi

# Download installer from appropriate URL
echo "Downloading Tableau Bridge $VERSION installer..." >&2
BRIDGE_URL="https://downloads.tableau.com/tssoftware/TableauBridge-${VERSION}.x86_64.rpm"

if ! wget -q -O "tableau-bridge.rpm" "$BRIDGE_URL"; then
    echo "Error: Failed to download Bridge installer" >&2
    exit 1
fi

# output the file stats via ls and also show its full path
ls -lh tableau-bridge.rpm >&2
if [ $? -ne 0 ]; then
    echo "Error: Failed to list downloaded file" >&2
    exit 1
fi

echo "Full path of downloaded file: $(realpath tableau-bridge.rpm)" >&2

echo "Fetch completed for $COMPONENT_NAME:$VERSION" >&2