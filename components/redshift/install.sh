#!/bin/bash
set -e

# --- Configure Amazon Redshift ODBC Driver using odbcinst ---
echo "Configuring Amazon Redshift ODBC driver..."

# Create temporary driver configuration file
TEMP_DRIVER_CONFIG=$(mktemp)
cat > "$TEMP_DRIVER_CONFIG" << EOL
[Amazon Redshift (x64)]
Description=Amazon Redshift ODBC Driver (64-bit)
Driver=/opt/amazon/redshiftodbc/lib/64/libamazonredshiftodbc64.so
EOL

# Register the driver using odbcinst
if odbcinst -i -d -f "$TEMP_DRIVER_CONFIG"; then
    echo "Successfully registered Amazon Redshift ODBC driver"
else
    echo "Error: Failed to register Amazon Redshift ODBC driver" >&2
    rm "$TEMP_DRIVER_CONFIG"
    exit 1
fi

# Clean up
rm "$TEMP_DRIVER_CONFIG"

# Verify driver registration
if odbcinst -q -d -n "Amazon Redshift (x64)"; then
    echo "Verified Amazon Redshift ODBC driver registration"
else
    echo "Warning: Driver verification failed, but installation might still be okay"
fi

echo "Amazon Redshift ODBC driver configuration complete"