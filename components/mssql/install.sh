#!/bin/bash
set -euxo pipefail

# Check if it's an RPM-based system
if ! [ -f /etc/redhat-release ] && ! [ -f /etc/system-release-cpe ]; then
    echo "Error: This script is intended for RPM-based distributions (RHEL, CentOS, Oracle Linux)."
    exit 1
fi

# Set up Microsoft repository
echo "Installing Microsoft repository configuration..."
if [ -f dist/mssql/microsoft.asc ]; then
    # For Amazon Linux 2023
    rpm --import dist/mssql/microsoft.asc
    cp dist/mssql/mssql.repo /etc/yum.repos.d/
    rm -f dist/mssql/microsoft.asc dist/mssql/mssql.repo
else
    # For RHEL and other compatible systems
    yum install -y dist/mssql/packages-microsoft-prod.rpm
fi

# Remove potential conflicting packages (as per documentation)
echo "Removing potential conflicting packages..."
yum remove -y unixODBC-utf16 unixODBC-utf16-devel || echo "No conflicting packages found or removal failed (continuing)."

# Install msodbcsql17 and mssql-tools, accepting EULA
echo "Installing msodbcsql17 and mssql-tools..."
ACCEPT_EULA=Y yum install -y msodbcsql17 mssql-tools

# Optional: Install unixODBC development headers (often needed)
echo "Installing unixODBC development headers..."
yum install -y unixODBC-devel

# Clean up downloaded repo package
echo "Cleaning up repo package..."
rm -f dist/mssql/packages-microsoft-prod.rpm

# Verify installation (optional but good practice)
echo "Verifying driver registration..."
odbcinst -q -d -n "ODBC Driver 17 for SQL Server" || echo "Verification command failed, but installation might still be okay."

echo "MSODBCSQL17 installation complete."
# Note: The PATH for mssql-tools (/opt/mssql-tools/bin) should be handled
# by the main Dockerfile or environment setup if needed globally.