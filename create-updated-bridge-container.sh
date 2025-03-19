#!/bin/bash

# Default to non-verbose mode
VERBOSE=false
LOG_DIR="logs"
LOG_FILE="${LOG_DIR}/build-$(date +%Y%m%d-%H%M%S).log"

# Create logs directory
mkdir -p "$LOG_DIR"

# Store version tracking state
declare -a major_minor_latest
latest_build=""

# Parse command line arguments
while getopts "vb:" opt; do
    case $opt in
        v) VERBOSE=true ;;
        b) BUILD_NUMBER="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

# Function to parse build number into components
parse_build_number() {
    local build="$1"
    local major="${build:0:4}"
    local minor="${build:4:1}"
    echo "$major $minor"
}

# Function to validate build number format and components
validate_build_number() {
    local build="$1"
    
    # Check basic format
    if ! [[ $build =~ ^[0-9]{4}[0-9]\.[0-9]{2}\.[0-9]{4}\.[0-9]{4}$ ]]; then
        echo "Invalid build number format. Expected: YYYYN.YY.MMDD.HHMM" >&2
        exit 1
    fi
    
    # Extract components
    local major="${build:0:4}"
    local minor="${build:4:1}"
    local year="${build:6:2}"
    local month="${build:9:2}"
    local day="${build:11:2}"
    local hour="${build:14:2}"
    local minute="${build:16:2}"
    
    # Validate date/time components
    if [[ "$month" -lt 1 || "$month" -gt 12 ]]; then
        echo "Invalid month in build number: $month" >&2
        exit 1
    fi
    if [[ "$day" -lt 1 || "$day" -gt 31 ]]; then
        echo "Invalid day in build number: $day" >&2
        exit 1
    fi
    if [[ "$hour" -lt 0 || "$hour" -gt 23 ]]; then
        echo "Invalid hour in build number: $hour" >&2
        exit 1
    fi
    if [[ "$minute" -lt 0 || "$minute" -gt 59 ]]; then
        echo "Invalid minute in build number: $minute" >&2
        exit 1
    fi
}

# Check if build is latest in its major.minor by comparing with existing tags
is_latest_in_major_minor() {
    local build="$1"
    local major="${build:0:4}"
    local minor="${build:4:1}"
    
    # Get all existing build number tags for this major.minor
    local existing_tags=$(docker images tableau-bridge --format "{{.Tag}}" | grep -E "^${major}${minor}\.[0-9]{2}\.[0-9]{4}\.[0-9]{4}$" || true)
    
    # If no builds exist, this is the latest
    if [[ -z "$existing_tags" ]]; then
        return 0
    fi
    
    # Check if any existing build has a higher build date
    while read -r existing_build; do
        if [[ "${existing_build:6}" > "${build:6}" ]]; then
            return 1
        fi
    done <<< "$existing_tags"
    
    return 0
}

# Check if build is latest overall by comparing with all existing tags
is_latest_overall() {
    local build="$1"
    local major="${build:0:4}"
    local minor="${build:4:1}"
    
    # Get all existing build number tags
    local existing_tags=$(docker images tableau-bridge --format "{{.Tag}}" | grep -E '^[0-9]{5}\.[0-9]{2}\.[0-9]{4}\.[0-9]{4}$' || true)
    
    # If no builds exist, this is the latest
    if [[ -z "$existing_tags" ]]; then
        return 0
    fi
    
    # Check if any existing build has higher major, minor, or build date
    while read -r existing_build; do
        local existing_major="${existing_build:0:4}"
        local existing_minor="${existing_build:4:1}"
        
        if [[ "$existing_major" -gt "$major" ]] || \
           [[ "$existing_major" -eq "$major" && "$existing_minor" -gt "$minor" ]] || \
           [[ "$existing_major" -eq "$major" && "$existing_minor" -eq "$minor" && "${existing_build:6}" > "${build:6}" ]]; then
            return 1
        fi
    done <<< "$existing_tags"
    
    return 0
}

# Tag the image based on build number and conditions
tag_image() {
    local build="$1"
    local major_minor="$(echo "$build" | awk -F '.' '{print substr($1, 1, 4)"."substr($1, 5, 6)}')"
    
    # Always tag with full build number
    run_cmd "docker tag tableau-bridge:'$build' tableau-bridge:'$build'" \
        "Tagging image with build number $build"
    
    # Tag with major.minor if latest in that version
    if is_latest_in_major_minor "$build"; then
        run_cmd "docker tag tableau-bridge:'$build' tableau-bridge:'$major_minor'" \
            "Tagging image with version $major_minor"
    fi
    
    # Tag as latest if highest overall
    if is_latest_overall "$build"; then
        run_cmd "docker tag tableau-bridge:'$build' tableau-bridge:latest" \
            "Tagging image as latest"
        latest_build="$build"
    fi
}

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

# Get or validate build number
if [[ -n "$BUILD_NUMBER" ]]; then
    echo "Using specified build number: $BUILD_NUMBER"
    validate_build_number "$BUILD_NUMBER"
else
    echo "Fetching latest Tableau Bridge version..."
    # Get the latest Bridge build number from the releases page
    BRIDGE_PAGE=$(curl -s "https://www.tableau.com/support/releases/bridge/latest")
    BUILD_NUMBER=$(echo "$BRIDGE_PAGE" | grep -o '[0-9]\{5\}\.[0-9]\{2\}\.[0-9]\{4\}\.[0-9]\{4\}' | head -1)

    if [ -z "$BUILD_NUMBER" ]; then
        echo "Error: Could not find latest Bridge build number"
        exit 1
    fi
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
# REDSHIFT_PAGE=$(curl -s "https://docs.aws.amazon.com/redshift/latest/mgmt/odbc20-install-linux.html")
REDSHIFT_PAGE=$(curl -s "https://docs.aws.amazon.com/redshift/latest/mgmt/odbc-driver-linux-how-to-install.html")
REDSHIFT_URL=$(echo "$REDSHIFT_PAGE" | grep -o 'https://s3.amazonaws.com/redshift-downloads/drivers/odbc/[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/AmazonRedshiftODBC-64-bit-[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9-]\+\.x86_64\.rpm' | head -1)

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
    run_cmd "wget --no-check-certificate -q -O '$TMP_REDSHIFT_FILE' '$REDSHIFT_URL'" "Downloading Redshift ODBC driver..."
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
    image_time=$(docker image inspect tableau-bridge:"$BUILD_NUMBER" --format='{{.Created}}' | date -d "$(cut -d'.' -f1)" "+%s")
    
    if check_source_files "$image_time"; then
        echo "No source files have been modified since last build. Skipping build."
    else
        run_cmd "docker buildx build --platform=linux/amd64 -t tableau-bridge:'$BUILD_NUMBER' ." "Rebuilding Docker image due to source modifications..."
    fi
else
    run_cmd "docker buildx build --platform=linux/amd64 -t tableau-bridge:'$BUILD_NUMBER' ." "Building Docker image..."
fi

# Apply smart tagging
tag_image "$BUILD_NUMBER"

echo "Docker image built and tagged successfully!"
echo "Build logs available at: $LOG_FILE"
