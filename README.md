# Tableau Bridge Docker Container

This Docker container runs Tableau Bridge on Amazon Linux 2023. It leverages an automated update mechanism to download the latest Bridge RPM and Amazon Redshift ODBC drivers, ensuring your container is always up-to-date.

## Prerequisites

1. Docker installed on your system.
2. A shell environment with `curl`, `wget`, `grep`, `sed`, and `docker` available.
3. A Tableau Site admin Personal Access Token (PAT).

## Overview

Instead of manually supplying the Tableau Bridge RPM package and Amazon Redshift ODBC drivers, the provided script `create-updated-bridge-container.sh` automatically:
- Fetches the latest Tableau Bridge build number and downloads the corresponding RPM.
- Retrieves the latest Amazon Redshift ODBC driver and caches it.
- Places the downloaded Redshift driver into the `drivers` directory.
- Builds and tags the Docker image with both the full build number and a simplified version.

The Docker image uses Amazon Linux 2023 as a base and pre-installs necessary dependencies. It also automatically installs drivers using the `drivers/install.sh` script.

## Setup Instructions

### 1. Update and Build the Docker Image

Run the `create-updated-bridge-container.sh` script from the project root. This script handles fetching the latest versions and building the Docker image.

For standard execution:
```bash
./create-updated-bridge-container.sh
```

For verbose logging, add the `-v` flag:
```bash
./create-updated-bridge-container.sh -v
```

The script will:
- Download and cache the latest Tableau Bridge RPM.
- Download and cache the latest Amazon Redshift ODBC driver.
- Move the downloaded driver into the `drivers` directory.
- Build the Docker image if it does not already exist, tagging it with both the full build number and a simplified version.

### 2. Dockerfile and Drivers Installation

- The `Dockerfile`:
  - Uses Amazon Linux 2023 as the base image.
  - Sets locale environment variables.
  - Installs `unixODBC` and other dependencies.
  - Creates necessary directories, including `/drivers` and `/opt/tableau/tableau_driver/jdbc`.
  - Copies the `drivers/` directory into the container.
  - Executes the `drivers/install.sh` script to install all RPM files and copy JDBC drivers.
  - Installs the Tableau Bridge RPM.
  - Sets up a volume for Bridge logs and a default working directory.

- The `drivers/install.sh` script:
  - Iterates over all RPM files in the directory and installs them.
  - Copies the `jdbc` folder to `/opt/tableau/tableau_driver/jdbc`.

Example `drivers/install.sh`:
```bash
#!/bin/bash
# Install all RPM files in the current directory
for rpm in *.rpm; do
    if [ -e "$rpm" ]; then
        echo "Installing $rpm..."
        yum --nogpgcheck localinstall -y "$rpm"
    fi
done

# Copy JDBC drivers to the correct location
cp -r jdbc /opt/tableau/tableau_driver/jdbc
```

- You can customize the `Dockerfile` and `drivers/install.sh` script to include additional dependencies or configurations.

### 3. Container Management

The project includes a `bridge-manager.sh` script to help manage the lifecycle of Bridge containers. This script provides an easy-to-use interface for users with minimal Docker experience.

Available commands:
```bash
# List all Bridge containers (running and stopped)
./bridge-manager.sh list

# List available Bridge Docker images
./bridge-manager.sh images

# Start a new Bridge container (interactive version selection)
./bridge-manager.sh start \
    -l "/path/to/bridge/logs" \
    -t "/path/to/token.json" \
    -u "your-email@domain.com" \
    -n "your-bridge-name" \
    -s "your-site-name" \
    -i "MyToken"

# Start a new Bridge container (specific version)
./bridge-manager.sh start \
    -v "2024.1" \
    -l "/path/to/bridge/logs" \
    -t "/path/to/token.json" \
    -u "your-email@domain.com" \
    -n "your-bridge-name" \
    -s "your-site-name" \
    -i "MyToken"

# Start with optional pool ID
./bridge-manager.sh start \
    -v "2024.1" \
    -l "/path/to/bridge/logs" \
    -t "/path/to/token.json" \
    -u "your-email@domain.com" \
    -n "your-bridge-name" \
    -s "your-site-name" \
    -p "your-pool-id" \
    -i "MyToken"

# Stop a running container
./bridge-manager.sh stop container-name

# Restart a container
./bridge-manager.sh restart container-name

# Open a shell in a running container for troubleshooting
./bridge-manager.sh shell container-name

# View live logs of a running container
./bridge-manager.sh logs container-name
```

For detailed usage information, run:
```bash
./bridge-manager.sh
```

#### Version Selection
When starting a container, you can specify the Bridge version in two ways:
1. Use the `-v` flag to specify a version (e.g., `-v 2024.1` or `-v 20241.23.0202.1000`)
2. Omit the `-v` flag to get an interactive menu of available versions

The script will:
- For exact version matches (e.g., `-v 2024.1`): Use that specific version
- For partial matches: Use the first matching version
- For interactive selection: Display a numbered list of available versions to choose from

Note: When starting a container, the script automatically creates a unique logs directory for each container using the format `container-name-YYYYMMDD-HHMMSS` within the specified logs path. This ensures that log files from different containers don't conflict with each other.

### 4. Token Configuration

Create a JSON file containing your PAT token, for example `token.json`:
```json
{
    "MyToken": "your-pat-token-here"
}
```

## Monitoring

Bridge logs are available in container-specific directories under the mounted logs directory on your host machine. Each container gets its own timestamped directory to prevent log file conflicts when running multiple containers.

## Security Notes

- Store your PAT token securely and restrict access to the token file.
- Use one PAT token per Bridge client as recommended by Tableau.
- Ensure proper file permissions on mounted volumes.

## Upgrading

To upgrade the Bridge client:
1. Run the `create-updated-bridge-container.sh` script to fetch the latest releases and rebuild the Docker image if necessary.
2. Ensure you have a PAT you can dedicate to the new instance of the Bridge client.
3. Test the new image with a subset of your workload.
4. Gradually replace existing containers with the updated version.
5. Monitor for stability before full deployment.

## Container Configuration Management

When starting a Bridge container, the script performs several checks:
- If a container with the specified name already exists:
  1. Checks if the configuration (user email, site, token ID, pool ID, and image) matches
  2. If configurations match and container is running: No action needed
  3. If configurations match but container is stopped: Automatically starts the container
  4. If configurations differ: Stops and removes the old container, then creates a new one
- For new containers:
  1. Creates a unique timestamped logs directory
  2. Sets up volume mounts for logs and token file
  3. Configures container with restart policy and specified parameters

## Troubleshooting

If you encounter issues:
- Ensure all required parameters are provided when starting a container
- Verify that the PAT token file exists and is readable
- Check that the PAT token has not expired
- Review logs using:
  * Container-specific logs directory under the mounted logs path
  * Live container logs using `./bridge-manager.sh logs container-name`
- Use `./bridge-manager.sh shell container-name` to access a running container's shell for advanced troubleshooting