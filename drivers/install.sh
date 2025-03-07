#!/bin/bash

# Install all RPM files in the current directory
for rpm in *.rpm; do
    if [ -e "$rpm" ]; then
        echo "Installing $rpm..."
        yum --nogpgcheck localinstall -y "$rpm"
    fi
done

# Copy jdbc drivers to the correct location
cp -r jdbc/* /opt/tableau/tableau_driver/jdbc

# Install Redshift ODBC configuration
odbcinst -i -d -f /opt/amazon/redshiftodbcx64/odbcinst.ini