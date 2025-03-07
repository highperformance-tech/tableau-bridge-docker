# Tableau Bridge Docker Container

This Docker container runs Tableau Bridge on Amazon Linux 2023. It leverages an automated update mechanism to download the latest Bridge RPM and Amazon Redshift ODBC drivers, ensuring your container is always up-to-date.

## Prerequisites

1. Docker installed on your system.
2. A shell environment with `curl`, `wget`, `grep`, `sed`, and `docker` available.
3. A Tableau Site admin Personal Access Token (PAT).

## Directory Structure

The project requires the following directory structure:
```
tableau-bridge-docker/
├── cache/              # Cached downloads of Bridge RPM and drivers
├── drivers/            # ODBC and JDBC drivers
│   ├── install.sh     # Driver installation script
│   └── jdbc/          # JDBC driver files
└── logs/              # Container-specific log directories
```

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

For standard execution (uses latest Bridge version):
```bash
./create-updated-bridge-container.sh
```

For verbose logging, add the `-v` flag:
```bash
./create-updated-bridge-container.sh -v
```

To build a specific version, use the `-b` flag with a build number:
```bash
./create-updated-bridge-container.sh -b 20243.25.0114.1153
```

The build number format is `{major}{minor}.{YY}.{MMDD}.{HHMM}`, where:
- major: Major version number (e.g., 2024)
- minor: Minor version number (single digit)
- YY: Two-digit build date year
- MMDD: Two-digit month and two-digit day of build
- HHMM: Two-digit hour and minute in 24-hour format

The script will validate the build number format and components before attempting to download and build that specific version.

The script will:
- Download and cache the latest Tableau Bridge RPM in the `cache` directory.
- Download and cache the latest Amazon Redshift ODBC driver.
- Move the downloaded driver into the `drivers` directory.
- Build the Docker image if it does not already exist, tagging it with:
  * Full build number (e.g., 20243.25.0114.1153)
  * Major.minor version (e.g., 2024.3) if it's the latest build in that version
  * Latest tag if it's the highest version with the most recent build date

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

# Remove a stopped container
./bridge-manager.sh remove container-name

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

Note: When starting a container, the script automatically creates a unique logs directory for each container using the format `container-name` within the specified logs path. This ensures that log files from different containers don't conflict with each other.

### 4. Token Configuration

Create a JSON file containing your PAT token, for example `token.json`:
```json
{
    "MyToken": "your-pat-token-here"
}
```

## Container Configuration Management

When starting a Bridge container, the script performs several checks:
- If a container with the specified name already exists:
  1. Checks if the configuration (user email, site, token ID, pool ID, and image) matches
  2. If configurations match and container is running: No action needed
  3. If configurations match but container is stopped: Automatically starts the container
  4. If configurations differ: Stops and removes the old container, then creates a new one
- For new containers:
  1. Creates a unique logs directory (`container-name`)
  2. Sets up volume mounts for logs and token file
  3. Configures container with restart policy (`unless-stopped`) and specified parameters

## Security Best Practices

### Container Security
1. Resource Isolation:
   - Container runs with default Docker isolation
   - Volume mounts are restricted to logs and token file
   - Network access is controlled by Docker networking

2. Token Management:
   - Store PAT tokens securely with restricted file permissions
   - Use one PAT token per Bridge client
   - Regularly rotate PAT tokens
   - Keep token files outside of version control

3. Access Controls:
   - Restrict access to Docker daemon
   - Maintain proper file permissions on host volumes
   - Monitor container logs for security events

## Monitoring and Logging

### Log Management
- Each container gets a unique logs directory
- Logs are available in container-specific directories under the mounted logs path
- Live logs can be viewed using `bridge-manager.sh logs container-name`

### Health Monitoring
1. Container Status:
   - Use `bridge-manager.sh list` to view container status
   - Check container resource usage with Docker stats: `docker stats container-name`
   - Monitor Bridge client connectivity in logs

2. Connection Status:
   - Bridge client connectivity to Tableau Server
   - Data source connection status
   - Pool membership status (if applicable)

## Troubleshooting

### Common Issues and Solutions

1. Container Startup Failures:
   - Verify token file exists and has correct permissions
   - Check logs for authentication errors
   - Ensure required ports are available
   - Verify resource constraints aren't exceeded

2. Authentication Issues:
   - Confirm PAT token hasn't expired
   - Verify token file format is correct
   - Check user permissions on Tableau Cloud
   - Ensure site name matches exactly

3. Data Source Connectivity:
   - Verify ODBC/JDBC drivers are properly installed
   - Check network connectivity to data sources
   - Review driver configurations
   - Ensure credentials are correct

4. Driver-Related Issues:
   - Verify driver installation in container
   - Check driver compatibility with data sources
   - Review driver logs for errors
   - Ensure driver paths are correct

### Troubleshooting Tools
1. Container Shell Access:
   ```bash
   ./bridge-manager.sh shell container-name
   ```
2. Live Log Viewing:
   ```bash
   ./bridge-manager.sh logs container-name
   ```
3. Container Information:
   ```bash
   docker inspect container-name
   ```

## Upgrading

To upgrade the Bridge client:
1. Run the `create-updated-bridge-container.sh` script to fetch the latest releases and rebuild the Docker image if necessary.
2. Ensure you have a PAT you can dedicate to the new instance of the Bridge client.
3. Test the new image with a subset of your workload.
4. Gradually replace existing containers with the updated version.
5. Monitor for stability before full deployment.

## Additional Resources

- [Tableau Bridge Documentation](https://help.tableau.com/current/online/en-us/to_bridge_install.htm)
- [Docker Documentation](https://docs.docker.com/)
- [Project Management Documentation](docs/bridge-environment-management.md)