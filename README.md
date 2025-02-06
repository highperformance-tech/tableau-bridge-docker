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
- Build the Docker image if it does not already exist, tagging it with the full build number and a simplified version.

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

### 3. Run the Container

Create a JSON file containing your PAT token, for example `token.json`:
```json
{
    "MyToken": "your-pat-token-here"
}
```

Run the container with mounted volumes for logs and the token file:
```bash
docker run -it \
    --volume /path/to/bridge/logs:/root/Documents/My_Tableau_Bridge_Repository/Logs \
    --volume /path/to/token.json:/opt/tableau/token.json \
    tableau-bridge --patTokenId="MyToken" --userEmail="your-email@domain.com" --client="your-bridge-name" --site="your-site-name" --patTokenFile="/opt/tableau/token.json" --poolId="your-pool-id"
```

## Monitoring

Bridge logs are available in the mounted logs directory on your host machine.

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

## Troubleshooting

If you encounter issues when starting the Bridge client:
- Ensure all required parameters are provided.
- Verify that the PAT token file exists and is readable.
- Check that the PAT token has not expired.
- For detailed logs, review the logs in the mounted logs directory.