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

# Install Redshift ODBC configuration, if it exists:
if [ -f /opt/amazon/redshiftodbcx64/odbcinst.ini ]; then
    echo "Installing Redshift ODBC driver configuration..."
    odbcinst -i -d -f /opt/amazon/redshiftodbcx64/odbcinst.ini
elif [ -f /opt/amazon/redshiftodbc/Setup/odbcinst.ini ]; then
    echo "Installing Redshift ODBC driver configuration from alternative location..."
    odbcinst -i -d -f /opt/amazon/redshiftodbc/Setup/odbcinst.ini
else
    echo "Redshift ODBC driver configuration file not found."
    echo "Please ensure that the driver is installed correctly."
fi