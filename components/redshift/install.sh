#!/bin/bash
set -e
# --- Add Redshift ODBC Driver Configuration ---
echo "Configuring Amazon Redshift ODBC driver in /etc/odbcinst.ini..."

ODBCINST_PATH="/etc/odbcinst.ini"
DRIVER_NAME="Amazon Redshift (x64)"
DRIVER_SECTION_HEADER="[$DRIVER_NAME]"
DRIVER_DESC="Description=Amazon Redshift ODBC Driver (64-bit)"
# Assuming default install path from AWS docs
DRIVER_LIB_PATH="/opt/amazon/redshiftodbc/lib/64/libamazonredshiftodbc64.so"
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
# Using grep -q -F -x to check for exact, fixed string match of the whole line
if ! grep -q -F -x "$ODBC_DRIVERS_SECTION_HEADER" "$TEMP_ODBCINST"; then
  echo "Adding '$ODBC_DRIVERS_SECTION_HEADER' section header to $ODBCINST_PATH"
  # Add a newline before adding the section if the file is not empty
  [ -s "$TEMP_ODBCINST" ] && echo "" >> "$TEMP_ODBCINST"
  echo "$ODBC_DRIVERS_SECTION_HEADER" >> "$TEMP_ODBCINST"
  MODIFIED=1
fi

# 2. Ensure Driver entry exists (append if missing anywhere)
if ! grep -q -F -x "$ODBC_DRIVERS_ENTRY" "$TEMP_ODBCINST"; then
  echo "Adding driver entry '$ODBC_DRIVERS_ENTRY' to $ODBCINST_PATH"
  # Append the entry. If the section header was just added, it follows it.
  # If the section header existed, it's appended at the end. This is generally acceptable.
  echo "$ODBC_DRIVERS_ENTRY" >> "$TEMP_ODBCINST"
  MODIFIED=1
fi

# 3. Ensure the specific driver definition section exists
if ! grep -q -F -x "$DRIVER_SECTION_HEADER" "$TEMP_ODBCINST"; then
  echo "Adding driver section '$DRIVER_SECTION_HEADER' to $ODBCINST_PATH"
  {
    # Add a blank line for separation only if the file isn't empty/just created
    [ -s "$TEMP_ODBCINST" ] && echo "" 
    echo "$DRIVER_SECTION_HEADER"
    echo "$DRIVER_DESC"
    echo "$DRIVER_PATH_LINE"
  } >> "$TEMP_ODBCINST"
  MODIFIED=1
fi

# Replace original file only if changes were made
if [ "$MODIFIED" -eq 1 ]; then
  # Use cat and redirect to preserve permissions, unlike mv
  cat "$TEMP_ODBCINST" > "$ODBCINST_PATH"
  echo "Updated $ODBCINST_PATH."
else
  echo "$ODBCINST_PATH already appears configured for '$DRIVER_NAME'."
fi

rm "$TEMP_ODBCINST"

echo "Amazon Redshift ODBC driver configuration check/update complete."
# --- End Redshift ODBC Driver Configuration ---