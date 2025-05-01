#!/bin/bash
set -e

# --- Install Snowflake ODBC Driver ---
echo "Installing Snowflake ODBC driver..."

# Install the downloaded RPM
if ! rpm -i snowflake-odbc.rpm; then
    echo "Error: Failed to install Snowflake ODBC driver" >&2
    exit 1
fi

# --- Configure Snowflake ODBC Driver in odbcinst.ini ---
echo "Configuring Snowflake ODBC driver in /etc/odbcinst.ini..."

ODBCINST_PATH="/etc/odbcinst.ini"
DRIVER_NAME="Snowflake"
DRIVER_SECTION_HEADER="[$DRIVER_NAME]"
DRIVER_DESC="Description=Snowflake ODBC Driver (64-bit)"
DRIVER_LIB_PATH="/usr/lib64/snowflake/odbc/lib/libSnowflake.so"
DRIVER_PATH_LINE="Driver=$DRIVER_LIB_PATH"
ODBC_DRIVERS_ENTRY="$DRIVER_NAME=Installed"
ODBC_DRIVERS_SECTION_HEADER="[ODBC Drivers]"

# Ensure the file exists
touch "$ODBCINST_PATH"

# Use temp file for modifications
TEMP_ODBCINST=$(mktemp)
cp "$ODBCINST_PATH" "$TEMP_ODBCINST"
MODIFIED=0

# 1. Ensure [ODBC Drivers] section header exists
if ! grep -q -F -x "$ODBC_DRIVERS_SECTION_HEADER" "$TEMP_ODBCINST"; then
    echo "Adding '$ODBC_DRIVERS_SECTION_HEADER' section header to $ODBCINST_PATH"
    # Add a newline before adding the section if the file is not empty
    [ -s "$TEMP_ODBCINST" ] && echo "" >> "$TEMP_ODBCINST"
    echo "$ODBC_DRIVERS_SECTION_HEADER" >> "$TEMP_ODBCINST"
    MODIFIED=1
fi

# 2. Ensure Driver entry exists
if ! grep -q -F -x "$ODBC_DRIVERS_ENTRY" "$TEMP_ODBCINST"; then
    echo "Adding driver entry '$ODBC_DRIVERS_ENTRY' to $ODBCINST_PATH"
    echo "$ODBC_DRIVERS_ENTRY" >> "$TEMP_ODBCINST"
    MODIFIED=1
fi

# 3. Ensure the specific driver definition section exists
if ! grep -q -F -x "$DRIVER_SECTION_HEADER" "$TEMP_ODBCINST"; then
    echo "Adding driver section '$DRIVER_SECTION_HEADER' to $ODBCINST_PATH"
    {
        # Add a blank line for separation only if the file isn't empty
        [ -s "$TEMP_ODBCINST" ] && echo ""
        echo "$DRIVER_SECTION_HEADER"
        echo "$DRIVER_DESC"
        echo "$DRIVER_PATH_LINE"
    } >> "$TEMP_ODBCINST"
    MODIFIED=1
fi

# Replace original file only if changes were made
if [ "$MODIFIED" -eq 1 ]; then
    # Use cat and redirect to preserve permissions
    cat "$TEMP_ODBCINST" > "$ODBCINST_PATH"
    echo "Updated $ODBCINST_PATH"
else
    echo "$ODBCINST_PATH already appears configured for '$DRIVER_NAME'"
fi

rm "$TEMP_ODBCINST"

echo "Snowflake ODBC driver installation and configuration complete"