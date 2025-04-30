#!/bin/bash
set -e

# Configuration file path
CONFIG_FILE="${1:-build-config.yml}"

# Check if configuration file exists
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Error: Configuration file '$CONFIG_FILE' not found."
  exit 1
fi

# Check for yq
if ! command -v yq &> /dev/null; then
  echo "Error: 'yq' is required but not installed."
  exit 1
fi

# Parse configuration
echo "Parsing configuration from $CONFIG_FILE..."
NAME=$(yq '.name' "$CONFIG_FILE")
TAGS=$(yq '.tags[]' "$CONFIG_FILE")
COMPONENTS=$(yq '.components | to_entries | .[] | [.key, .value] | join(",")' "$CONFIG_FILE")

echo "Building $NAME with components:"
echo "$COMPONENTS" | tr ' ' '\n'

# Validate components directory
for component_entry in $COMPONENTS; do
  component_name=$(echo "$component_entry" | cut -d, -f1)
  component_dir="components/$component_name"
  
  if [ ! -d "$component_dir" ]; then
    echo "Error: Component directory '$component_dir' not found."
    exit 1
  fi
  
  if [ ! -x "$component_dir/fetch.sh" ]; then
    echo "Error: Fetch script for '$component_name' not found or not executable."
    exit 1
  fi
  
  if [ ! -x "$component_dir/install.sh" ]; then
    echo "Error: Install script for '$component_name' not found or not executable."
    exit 1
  fi
done

# Fetch and install components sequentially
echo "Fetching and installing components..."

for component_entry in $COMPONENTS; do
  component_name=$(echo "$component_entry" | cut -d, -f1)
  component_version=$(echo "$component_entry" | cut -d, -f2)
  
  echo "Starting fetch: $component_name version $component_version"
  
  # Run fetch script
  if ! components/$component_name/fetch.sh "$component_version"; then
    echo "Error: Fetch process failed for $component_name"
    exit 1
  fi
  
  echo "Installing component: $component_name"
  if ! components/$component_name/install.sh; then
    echo "Error: Installation of component '$component_name' failed."
    exit 1
  fi
done