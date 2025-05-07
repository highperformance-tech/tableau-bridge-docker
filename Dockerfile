# Use Amazon Linux 2023 as base image
FROM amazonlinux:2023

# Set environment variables for locale
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Update system and install dependencies
RUN yum -y update && \
    yum -y install \
    unixODBC \
    glibc-langpack-en \
    findutils \
    dbus-libs \
    procps \
    wget \
    && yum clean all \
    && rm /etc/odbcinst.ini \
    && touch /etc/odbcinst.ini

# Create build directory for component installation, drivers, and Bridge logs
RUN mkdir -p /build /opt/tableau/tableau_driver/jdbc /root/Documents/My_Tableau_Bridge_Repository/Logs

# Install yq for build script
RUN curl -L https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq

# Copy build files and components
COPY components/ /build/components/
COPY build.sh build-config.yml /build/

# Execute build script to install components
RUN cd /build && \
    chmod +x build.sh && \
    ./build.sh build-config.yml && \
    cd / && \
    rm -rf /build

# Create volume mount point for logs
VOLUME /root/Documents/My_Tableau_Bridge_Repository/Logs

# Set working directory
WORKDIR /opt/tableau/tableau_bridge

ENV PATH="$PATH:/opt/mssql-tools/bin"

# Run Bridge in foreground
ENTRYPOINT ["/opt/tableau/tableau_bridge/bin/run-bridge.sh", "-e"]