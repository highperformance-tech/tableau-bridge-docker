# Use Amazon Linux 2023 as base image
FROM amazonlinux:2023

# Set environment variables for locale
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Update system and install dependencies
RUN yum -y update && \
    yum -y install unixODBC && \
    yum clean all

# Create directories for drivers and Bridge
RUN mkdir -p /opt/tableau/tableau_driver/jdbc && \
    mkdir -p /drivers

# Copy drivers directory (to be mounted at runtime)
COPY drivers/ /drivers/

# Install drivers
RUN cd /drivers && \
    chmod +x install.sh && \
    ./install.sh

# Install Tableau Bridge RPM
COPY tableau-bridge.rpm .
RUN ACCEPT_EULA=y yum install -y ./tableau-bridge.rpm && \
    rm -f tableau-bridge.rpm

# Create directory for Bridge logs
RUN mkdir -p /root/Documents/My_Tableau_Bridge_Repository/Logs

# Create volume mount point for logs
VOLUME /root/Documents/My_Tableau_Bridge_Repository/Logs

# Set working directory
WORKDIR /opt/tableau/tableau_bridge

# Run Bridge in foreground
ENTRYPOINT ["/bin/sh", "-c", "/opt/tableau/tableau_bridge/bin/run-bridge.sh", "-e"]