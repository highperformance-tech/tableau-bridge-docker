#!/bin/bash

# Set strict error handling
set -euo pipefail

# Default container name
DEFAULT_NAME="tableau-bridge"

# Help/Usage function
show_usage() {
    cat << EOF
Usage: $0 <command> [options]

Manage Tableau Bridge Docker containers lifecycle.

Commands:
    list                    List all Tableau Bridge containers (running and stopped)
    images                  List all available Tableau Bridge Docker images
    start [options]        Start a new Tableau Bridge container
    stop [-n name]         Stop a running container
    restart [-n name]      Restart a container
    shell [-n name]        Open an interactive shell in a running container

Start Options:
    -n <name>              Container name (default: tableau-bridge)
    -l <path>             Host directory for logs
    -t <path>             Host token file path
    -u <email>            User email
    -c <name>             Client/bridge name
    -s <site>             Site name
    -p <pool-id>          Pool ID (optional)
    -i <token-id>         PAT token ID

Examples:
    $0 list
    $0 images
    $0 start -l "/path/to/logs" -t "/path/to/token.json" -u "user@example.com" -c "bridge1" -s "site" -i "MyToken"
    $0 start -l "/path/to/logs" -t "/path/to/token.json" -u "user@example.com" -c "bridge1" -s "site" -p "pool1" -i "MyToken"
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
    local client_name=""
    local site_name=""
    local pool_id=""
    local token_id=""

    # Parse options
    while getopts "n:l:t:u:c:s:p:i:" opt; do
        case $opt in
            n) name="$OPTARG" ;;
            l) logs_path="$OPTARG" ;;
            t) token_path="$OPTARG" ;;
            u) user_email="$OPTARG" ;;
            c) client_name="$OPTARG" ;;
            s) site_name="$OPTARG" ;;
            p) pool_id="$OPTARG" ;;
            i) token_id="$OPTARG" ;;
            \?) echo "Invalid option: -$OPTARG" >&2; show_usage; exit 1 ;;
        esac
    done

    # Verify required parameters
    if [[ -z "$logs_path" || -z "$token_path" || -z "$user_email" || -z "$client_name" || 
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

    # Create container-specific logs directory
    local container_logs_dir
    container_logs_dir=$(create_container_logs_dir "$logs_path" "$name")
    echo "Created container-specific logs directory: $container_logs_dir"

    echo "Starting Tableau Bridge container '$name'..."
    
    # Build the docker run command
    local cmd="docker run -d \
        --name \"$name\" \
        --volume \"$container_logs_dir:/root/Documents/My_Tableau_Bridge_Repository/Logs\" \
        --volume \"$token_path:/opt/tableau/token.json\" \
        tableau-bridge \
        --patTokenId=\"$token_id\" \
        --userEmail=\"$user_email\" \
        --client=\"$client_name\" \
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