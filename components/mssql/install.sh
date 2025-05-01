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

# Explicitly register the driver using odbcinst
echo "Registering ODBC Driver 17 for SQL Server..."
TEMP_DRIVER_CONFIG=$(mktemp)
cat > "$TEMP_DRIVER_CONFIG" << EOL
[ODBC Driver 17 for SQL Server]
Description=Microsoft ODBC Driver 17 for SQL Server
Driver=/opt/microsoft/msodbcsql17/lib64/libmsodbcsql-17.so
UsageCount=1
EOL

# Register the driver using odbcinst
if odbcinst -i -d -f "$TEMP_DRIVER_CONFIG"; then
    echo "Successfully registered MSSQL ODBC driver"
else
    echo "Error: Failed to register MSSQL ODBC driver" >&2
    rm "$TEMP_DRIVER_CONFIG"
    exit 1
fi

# Clean up
rm "$TEMP_DRIVER_CONFIG"

# Verify driver registration
echo "Verifying driver registration..."
if odbcinst -q -d -n "ODBC Driver 17 for SQL Server"; then
    echo "Verified MSSQL ODBC driver registration"
else
    echo "Warning: Driver verification failed, but installation might still be okay"
fi

echo "MSODBCSQL17 installation and configuration complete."
# Note: The PATH for mssql-tools (/opt/mssql-tools/bin) should be handled
# by the main Dockerfile or environment setup if needed globally.