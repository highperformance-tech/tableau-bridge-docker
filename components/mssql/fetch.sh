#!/bin/bash
set -euxo pipefail

# Output directory
DEST_DIR="dist/mssql"
mkdir -p "$DEST_DIR"

# Check if it's an RPM-based system
if ! [ -f /etc/redhat-release ] && ! [ -f /etc/system-release-cpe ]; then
    echo "Error: This script is intended for RPM-based distributions (RHEL, CentOS, Oracle Linux)."
    exit 1
fi

# shellcheck disable=SC1091
. /etc/os-release
VERSION_ID_MAJOR=$(echo "$VERSION_ID" | cut -d '.' -f 1)
REPO_URL=""

# Determine repo URL based on RHEL/Oracle Linux version (v17 supports 6, 7, 8, 9)
# For Amazon Linux 2023, set up Microsoft repository manually
if [[ "$ID" == "amzn" && "$VERSION_ID_MAJOR" == "2023" ]]; then
    echo "Detected Amazon Linux 2023, setting up Microsoft repository manually..."
    # Create the repository configuration file
    cat > "$DEST_DIR/mssql.repo" << EOF
[packages-microsoft-com-prod]
name=Microsoft SQL Server packages
baseurl=https://packages.microsoft.com/rhel/9/prod/
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    # Download the Microsoft GPG key
    curl -sSL https://packages.microsoft.com/keys/microsoft.asc -o "$DEST_DIR/microsoft.asc"
    REPO_URL=""
elif [[ " 6 7 8 9 " == *" $VERSION_ID_MAJOR "* ]]; then
    REPO_URL="https://packages.microsoft.com/config/rhel/${VERSION_ID_MAJOR}/packages-microsoft-prod.rpm"
else
    echo "Unsupported RHEL/Oracle Linux/Amazon Linux version for msodbcsql17: $PRETTY_NAME"
    exit 1
fi

# Only download RPM package if we have a URL (not for Amazon Linux 2023)
if [[ -n "$REPO_URL" ]]; then
    echo "Downloading Microsoft repo package for $PRETTY_NAME..."
    curl -sSL -o "$DEST_DIR/packages-microsoft-prod.rpm" "$REPO_URL"
    echo "Microsoft repo package downloaded to $DEST_DIR/packages-microsoft-prod.rpm"
fi