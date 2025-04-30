#!/bin/bash
set -e

if [ -z "tableau-bridge.rpm" ]; then
    echo "Error: RPM file path is required" >&2
    exit 1
fi

if [ ! -f "tableau-bridge.rpm" ]; then
    echo "Error: RPM file not found at tableau-bridge.rpm" >&2
    exit 1
fi

echo "Installing Tableau Bridge..."

# Install the RPM package
ACCEPT_EULA=y yum install -y "tableau-bridge.rpm"

echo "Tableau Bridge installation completed"