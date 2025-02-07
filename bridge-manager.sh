#!/bin/bash

# Set strict error handling
set -euo pipefail

# Default container name
DEFAULT_NAME="tableau-bridge"
DEFAULT_IMAGE="tableau-bridge:latest"

# Help/Usage function
show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Manage Tableau Bridge Docker containers lifecycle.

Commands:
    list                  List all Tableau Bridge containers (running and stopped)
    images                List all available Tableau Bridge Docker images
    start [options]       Start a new Tableau Bridge container
    stop [-n name]        Stop a running container
    restart [-n name]     Restart a container
    shell [-n name]       Open an interactive shell in a running container

Start Options:
    -n <name>             Container and bridge name (default: tableau-bridge)
    -l <path>             Host directory for logs
    -t <path>             Host token file path
    -u <email>            User email
    -s <site>             Site name
    -p <pool-id>          Pool ID (optional)
    -i <token-id>         PAT token ID
    -v <version>          Bridge version to use (e.g., 2024.1, 20241.23.0202.1000)
                          If not specified, lists available versions for selection

Examples:
    $0 list
    $0 images
    $0 start -l "/path/to/logs" -t "/path/to/token.json" -u "user@example.com" -n "bridge1" -s "site" -i "MyToken"
    $0 start -v 2024.1 -l "/path/to/logs" -t "/path/to/token.json" -u "user@example.com" -n "bridge1" -s "site" -i "MyToken"
    $0 stop -n bridge1
    $0 restart -n bridge1
    $0 shell -n bridge1    # Open shell in running container
EOF
}

# Function to list containers
list_containers() {
    echo "Listing all Tableau Bridge containers:"
    docker ps -a --filter "name=tableau-bridge" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
}

# Function to list images
list_images() {
    echo "Available Tableau Bridge images:"
    docker images tableau-bridge --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedAt}}"
}

# Function to prompt for image selection
select_image() {
    local version="$1"
    local images
    
    # If version is provided, try to find an exact match first
    if [[ -n "$version" ]]; then
        if docker images "tableau-bridge:$version" --quiet | grep -q .; then
            echo "tableau-bridge:$version"
            return 0
        fi
        # If no exact match, try partial match
        images=$(docker images tableau-bridge --format "{{.Tag}}" | grep "$version" || true)
        if [[ -n "$images" ]]; then
            if [[ $(echo "$images" | wc -l) -eq 1 ]]; then
                echo "tableau-bridge:$images"
                return 0
            fi
        fi
        echo "No image found matching version: $version" >&2
        echo "Available versions:" >&2
        docker images tableau-bridge --format "{{.Tag}}" >&2
        exit 1
    fi

    # If no version specified or no match found, show selection menu
    images=$(docker images tableau-bridge --format "{{.Tag}}")
    if [[ -z "$images" ]]; then
        echo "No Tableau Bridge images found" >&2
        echo "Please run create-updated-bridge-container.sh first" >&2
        exit 1
    fi

    echo "Available Tableau Bridge versions:"
    select version in $images; do
        if [[ -n "$version" ]]; then
            echo "tableau-bridge:$version"
            return 0
        else
            echo "Invalid selection" >&2
            exit 1
        fi
    done
}

# Function to create container-specific logs directory
create_container_logs_dir() {
    local base_logs_path="$1"
    local container_name="$2"
    
    # Get a unique identifier based on timestamp and container name
    local container_dir="${base_logs_path}/${container_name}-$(date +%Y%m%d-%H%M%S)"
    
    # Create the container-specific logs directory
    mkdir -p "$container_dir"
    echo "$container_dir"
}

# Function to start container
start_container() {
    local name="$DEFAULT_NAME"
    local logs_path=""
    local token_path=""
    local user_email=""
    local site_name=""
    local pool_id=""
    local token_id=""
    local version=""

    # Parse options
    while getopts "n:l:t:u:s:p:i:v:" opt; do
        case $opt in
            n) name="$OPTARG" ;;
            l) logs_path="$OPTARG" ;;
            t) token_path="$OPTARG" ;;
            u) user_email="$OPTARG" ;;
            s) site_name="$OPTARG" ;;
            p) pool_id="$OPTARG" ;;
            i) token_id="$OPTARG" ;;
            v) version="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" >&2; show_usage; exit 1 ;;
        esac
    done

    # Verify required parameters
    if [[ -z "$logs_path" || -z "$token_path" || -z "$user_email" ||
          -z "$site_name" || -z "$token_id" ]]; then
        echo "Error: Missing required parameters" >&2
        show_usage
        exit 1
    fi

    # Verify paths exist
    if [[ ! -d "$logs_path" ]]; then
        echo "Error: Logs directory does not exist: $logs_path" >&2
        exit 1
    fi
    if [[ ! -f "$token_path" ]]; then
        echo "Error: Token file does not exist: $token_path" >&2
        exit 1
    fi

    # Select image version
    local image
    image=$(select_image "$version")
    echo "Using image: $image"

    # Create container-specific logs directory and ensure absolute path
    local container_logs_dir
    # Convert to absolute path if relative
    logs_path=$(cd "$logs_path" && pwd) || { echo "Error: Could not resolve logs directory path" >&2; exit 1; }
    container_logs_dir=$(create_container_logs_dir "$logs_path" "$name")
    echo "Created container-specific logs directory: $container_logs_dir"

    echo "Starting Tableau Bridge container '$name'..."
    
    # Build the docker run command
    local cmd="docker run -d \
        --name \"$name\" \
        --volume \"$container_logs_dir:/root/Documents/My_Tableau_Bridge_Repository/Logs\" \
        --volume \"$token_path:/opt/tableau/token.json\" \
        \"$image\" \
        --patTokenId=\"$token_id\" \
        --userEmail=\"$user_email\" \
        --client=\"$name\" \
        --site=\"$site_name\" \
        --patTokenFile=\"/opt/tableau/token.json\""

    # Add pool ID if provided
    if [[ -n "$pool_id" ]]; then
        cmd="$cmd --poolId=\"$pool_id\""
    fi

    # Execute the command
    eval "$cmd"

    echo "Container started successfully"
    echo "Logs will be available in: $container_logs_dir"
}

# Function to stop container
stop_container() {
    local name="$DEFAULT_NAME"
    
    while getopts "n:" opt; do
        case $opt in
            n) name="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" >&2; show_usage; exit 1 ;;
        esac
    done

    echo "Stopping container '$name'..."
    docker stop "$name"
    echo "Container stopped successfully"
}

# Function to restart container
restart_container() {
    local name="$DEFAULT_NAME"
    
    while getopts "n:" opt; do
        case $opt in
            n) name="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" >&2; show_usage; exit 1 ;;
        esac
    done

    echo "Restarting container '$name'..."
    docker restart "$name"
    echo "Container restarted successfully"
}

# Function to open shell in container
shell_container() {
    local name="$DEFAULT_NAME"
    
    while getopts "n:" opt; do
        case $opt in
            n) name="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" >&2; show_usage; exit 1 ;;
        esac
    done

    # Check if container exists and is running
    if ! docker ps --format '{{.Names}}' | grep -q "^${name}$"; then
        echo "Error: Container '$name' is not running" >&2
        exit 1
    fi

    echo "Opening shell in container '$name'..."
    docker exec -it "$name" /bin/bash
}

# Main script logic
if [[ $# -eq 0 ]]; then
    show_usage
    exit 1
fi

# Process commands
case "$1" in
    "list")
        list_containers
        ;;
    "images")
        list_images
        ;;
    "start")
        shift
        start_container "$@"
        ;;
    "stop")
        shift
        stop_container "$@"
        ;;
    "restart")
        shift
        restart_container "$@"
        ;;
    "shell")
        shift
        shell_container "$@"
        ;;
    *)
        echo "Unknown command: $1" >&2
        show_usage
        exit 1
        ;;
esac