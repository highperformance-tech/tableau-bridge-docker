#!/bin/bash

# Default to non-verbose mode
VERBOSE=false
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory
mkdir -p "$LOG_DIR"

# Parse command line arguments
while getopts "v" opt; do
    case $opt in
        v)
            VERBOSE=true
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Function to handle command execution and logging
run_cmd() {
    local cmd="$1"
    local msg="$2"
    
    echo "$msg"
    if [ "$VERBOSE" = true ]; then
        eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
    else
        eval "$cmd" >> "$LOG_FILE" 2>&1
    fi
    
    if [ ${PIPESTATUS[0]} -ne 0 ]; then
        echo "Error: Command failed. Check logs at $LOG_FILE for details."
        exit 1
    fi
}

# Function to check if a command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is required but not installed."
        exit 1
    fi
}

# Check required commands
check_command curl
check_command wget
check_command grep
check_command sed
check_command docker

# Set cache directory for downloads
CACHE_DIR="cache"
mkdir -p "$CACHE_DIR"

echo "Fetching latest Tableau Bridge version..."

# Get the latest Bridge build number from the releases page
BRIDGE_PAGE=$(curl -s "https://www.tableau.com/support/releases/bridge/latest")
BUILD_NUMBER=$(echo "$BRIDGE_PAGE" | grep -o '[0-9]\{5\}\.[0-9]\{2\}\.[0-9]\{4\}\.[0-9]\{4\}' | head -1)

if [ -z "$BUILD_NUMBER" ]; then
    echo "Error: Could not find latest Bridge build number"
    exit 1
fi

# Construct the full download URL
BRIDGE_URL="https://downloads.tableau.com/tssoftware/TableauBridge-${BUILD_NUMBER}.x86_64.rpm"

echo "Found latest Bridge build number: $BUILD_NUMBER"
echo "Generated download URL: $BRIDGE_URL"

# Download Bridge RPM with caching and enhanced error handling
BRIDGE_FILENAME=$(basename "$BRIDGE_URL")
CACHE_BRIDGE_FILE="$CACHE_DIR/$BRIDGE_FILENAME"
if [ -f "$CACHE_BRIDGE_FILE" ] && [ -s "$CACHE_BRIDGE_FILE" ]; then
    echo "Cached Bridge RPM found at $CACHE_BRIDGE_FILE. Using cached file."
else
    TMP_BRIDGE_FILE="$CACHE_BRIDGE_FILE.tmp"
    run_cmd "wget -q -O '$TMP_BRIDGE_FILE' '$BRIDGE_URL'" "Downloading Bridge RPM..."
    if [ ! -s "$TMP_BRIDGE_FILE" ]; then
        echo "Error: Failed to download a valid Bridge RPM"
        rm -f "$TMP_BRIDGE_FILE"
        exit 1
    fi
    mv "$TMP_BRIDGE_FILE" "$CACHE_BRIDGE_FILE"
fi
cp "$CACHE_BRIDGE_FILE" tableau-bridge.rpm
echo "Bridge RPM is ready."

echo "Fetching latest Redshift ODBC driver version..."

# Get the Redshift ODBC driver page
REDSHIFT_PAGE=$(curl -s "https://docs.aws.amazon.com/redshift/latest/mgmt/odbc20-install-linux.html")
REDSHIFT_URL=$(echo "$REDSHIFT_PAGE" | grep -o 'https://s3.amazonaws.com/redshift-downloads/drivers/odbc/[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/AmazonRedshiftODBC-64-bit-[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+\.x86_64\.rpm' | head -1)

if [ -z "$REDSHIFT_URL" ]; then
    echo "Error: Could not find Redshift ODBC driver download URL"
    exit 1
fi

echo "Found Redshift ODBC driver URL: $REDSHIFT_URL"
REDSHIFT_FILENAME=$(basename "$REDSHIFT_URL")
CACHE_REDSHIFT_FILE="$CACHE_DIR/$REDSHIFT_FILENAME"
if [ -f "$CACHE_REDSHIFT_FILE" ] && [ -s "$CACHE_REDSHIFT_FILE" ]; then
    echo "Cached Redshift ODBC driver found at $CACHE_REDSHIFT_FILE. Using cached file."
else
    TMP_REDSHIFT_FILE="$CACHE_REDSHIFT_FILE.tmp"
    run_cmd "wget -q -O '$TMP_REDSHIFT_FILE' '$REDSHIFT_URL'" "Downloading Redshift ODBC driver..."
    if [ ! -s "$TMP_REDSHIFT_FILE" ]; then
        echo "Error: Failed to download a valid Redshift ODBC driver"
        rm -f "$TMP_REDSHIFT_FILE"
        exit 1
    fi
    mv "$TMP_REDSHIFT_FILE" "$CACHE_REDSHIFT_FILE"
fi
cp "$CACHE_REDSHIFT_FILE" amazon-redshift-odbc.rpm
echo "Redshift ODBC driver is ready."

# Create drivers directory if it doesn't exist
mkdir -p drivers

# Move downloaded Redshift driver to drivers directory
mv amazon-redshift-odbc.rpm drivers/
echo "Downloads completed successfully!"

# Extract simplified version from build number (e.g., 20243.25.0114.1153 -> 2024.3)
VERSION=$(echo "$BUILD_NUMBER" | awk -F '.' '{print substr($1, 1, 4)"."substr($1, 5, 6)}')

# Function to check if any source files are newer than the image
check_source_files() {
    local image_time=$1
    local needs_rebuild=false
    local reason=""

    # Check Dockerfile
    if [ -f "Dockerfile" ]; then
        file_time=$(stat -c %Y "Dockerfile")
        if [ "$file_time" -gt "$image_time" ]; then
            needs_rebuild=true
            reason="Dockerfile has been modified"
        fi
    fi

    # Check tableau-bridge.rpm
    if [ -f "tableau-bridge.rpm" ]; then
        file_time=$(stat -c %Y "tableau-bridge.rpm")
        if [ "$file_time" -gt "$image_time" ]; then
            needs_rebuild=true
            reason="tableau-bridge.rpm has been modified"
        fi
    fi

    # Check all files in drivers directory
    if [ -d "drivers" ]; then
        while IFS= read -r file; do
            file_time=$(stat -c %Y "$file")
            if [ "$file_time" -gt "$image_time" ]; then
                needs_rebuild=true
                reason="Files in drivers directory have been modified"
                break
            fi
        done < <(find "drivers" -type f)
    fi

    if [ "$needs_rebuild" = true ]; then
        echo "Rebuild needed: $reason"
        return 1
    fi
    return 0
}

# Check if Docker image with current build number already exists
if docker image inspect tableau-bridge:"$BUILD_NUMBER" > /dev/null 2>&1; then
    echo "Docker image tableau-bridge:$BUILD_NUMBER exists, checking for modifications..."
    # Get image creation time - convert ISO 8601 to Unix timestamp
    image_time=$(docker image inspect tableau-bridge:"$BUILD_NUMBER" --format='{{.Created}}' | date -d "$(cut -d'.' -f1)" +%s)
    
    if check_source_files "$image_time"; then
        echo "No source files have been modified since last build. Skipping build."
    else
        run_cmd "docker buildx build --platform=linux/amd64 -t tableau-bridge:'$BUILD_NUMBER' ." "Rebuilding Docker image due to source modifications..."
    fi
else
    run_cmd "docker buildx build --platform=linux/amd64 -t tableau-bridge:'$BUILD_NUMBER' ." "Building Docker image..."
fi

echo "Tagging Docker image with version $VERSION..."
run_cmd "docker tag tableau-bridge:'$BUILD_NUMBER' tableau-bridge:'$VERSION'" "Tagging Docker image..."
run_cmd "docker tag tableau-bridge:'$BUILD_NUMBER' tableau-bridge:latest" "Tagging Docker image as latest..."

echo "Docker image built and tagged successfully!"
echo "Build logs available at: $LOG_FILE"
