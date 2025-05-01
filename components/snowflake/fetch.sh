#!/bin/bash
set -e

VERSION="$1"
COMPONENT_NAME="snowflake"

if [ -z "$VERSION" ]; then
    echo "Error: Version parameter is required" >&2
    exit 1
fi

# Function to compare two version strings using semver rules
# Returns:
#   1  if version1 > version2
#   0  if version1 = version2
#   -1 if version1 < version2
# Follows semver precedence:
#   - Major version (first number) has highest precedence
#   - Minor version (second number) has second highest precedence
#   - Patch version (third number) has lowest precedence
#   Example: 3.8.0 > 2.25.12 (because 3 > 2)
compare_versions() {
    # Early return if versions are identical
    if [[ $1 == $2 ]]; then
        echo 0
        return
    fi

    # Split versions into arrays using dot as delimiter
    local IFS=.
    local i ver1=($1) ver2=($2)

    # Ensure both arrays have same length by padding with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    for ((i=${#ver2[@]}; i<${#ver1[@]}; i++)); do
        ver2[i]=0
    done

    # Compare version components with proper numeric conversion
    # Using base 10 (10#) to ensure proper numeric comparison
    for ((i=0; i<${#ver1[@]}; i++)); do
        local v1=$((10#${ver1[i]:-0}))  # Convert to base 10, default to 0 if empty
        local v2=$((10#${ver2[i]:-0}))  # Convert to base 10, default to 0 if empty
        
        if ((v1 > v2)); then
            echo 1
            return
        fi
        if ((v1 < v2)); then
            echo -1
            return
        fi
    done

    # All components are equal
    echo 0
}

# Function to validate semver format
validate_version() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi
    return 0
}

# Function to scrape and return the latest version from Snowflake's downloads page
get_latest_version() {
    local repo_base="https://www.snowflake.com/en/developers/downloads/odbc/"
    local temp_file
    local latest_version=""
    
    # Create temporary file
    temp_file=$(mktemp)
    
    # Get directory listing from repository
    if ! curl -s -f "$repo_base" > "$temp_file"; then
        rm -f "$temp_file"
        echo "Error: Failed to access Snowflake repository" >&2
        exit 1
    fi
    
    # Extract version numbers from directory listing
    local versions
    versions=$(grep -oE 'snowflake-odbc-[0-9]+\.[0-9]+\.[0-9]+' "$temp_file" | cut -d'-' -f3 | tr -d '"/' | sort -u)
    
    # Clean up temporary file
    rm -f "$temp_file"
    
    if [ -z "$versions" ]; then
        echo "Error: No version numbers found in repository" >&2
        exit 1
    fi
    
    # Find the latest version by comparing all found versions
    while read -r version; do
        # Validate version format
        if ! validate_version "$version"; then
            continue
        fi
        
        if [ -z "$latest_version" ]; then
            latest_version="$version"
        else
            if [ "$(compare_versions "$version" "$latest_version")" -eq 1 ]; then
                latest_version="$version"
            fi
        fi
    done <<< "$versions"
    
    if [ -z "$latest_version" ]; then
        echo "Error: Failed to determine latest version" >&2
        exit 1
    fi
    
    echo "$latest_version"
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