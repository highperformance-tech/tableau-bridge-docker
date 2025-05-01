#!/bin/bash
set -e

# --- Install Snowflake ODBC Driver ---
echo "Installing Snowflake ODBC driver..."

# Install the downloaded RPM
if ! rpm -i snowflake-odbc.rpm; then
    echo "Error: Failed to install Snowflake ODBC driver" >&2
    exit 1
fi

# --- Configure Snowflake ODBC Driver using odbcinst ---
echo "Configuring Snowflake ODBC driver..."

# Create temporary driver configuration file
TEMP_DRIVER_CONFIG=$(mktemp)
cat > "$TEMP_DRIVER_CONFIG" << EOL
[Snowflake]
Description=Snowflake ODBC Driver (64-bit)
Driver=/usr/lib64/snowflake/odbc/lib/libSnowflake.so
EOL

# Register the driver using odbcinst
if odbcinst -i -d -f "$TEMP_DRIVER_CONFIG"; then
    echo "Successfully registered Snowflake ODBC driver"
else
    echo "Error: Failed to register Snowflake ODBC driver" >&2
    rm "$TEMP_DRIVER_CONFIG"
    exit 1
fi

# Clean up
rm "$TEMP_DRIVER_CONFIG"

# Verify driver registration
if odbcinst -q -d -n "Snowflake"; then
    echo "Verified Snowflake ODBC driver registration"
else
    echo "Warning: Driver verification failed, but installation might still be okay"
fi

echo "Snowflake ODBC driver installation and configuration complete"