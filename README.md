# Raspberry Pi Netboot Setup and Client Configuration

This repository provides scripts and instructions for setting up a Raspberry Pi netboot environment and configuring netboot clients. You can use these scripts to automate the process of downloading the latest Raspberry Pi OS Lite image, preparing the netboot environment, and adding new netboot clients.

## Prerequisites

Before using these scripts, ensure that the following dependencies are met:

- `curl`
- `kpartx`
- `rsync`
- `wget`
- `openssl`
- `rsync`
- `chown`

You can install these dependencies using your system's package manager.

## Raspberry Pi Netboot Setup (netboot-setup.sh)

### Configuration

The `netboot-setup.sh` script allows you to set up a Raspberry Pi netboot environment. You can configure the following variables in the script:

- `BASE_URL`: The base URL for downloading Raspberry Pi OS Lite images.
- `TMPIMG_DIR`: Temporary directory for image processing.
- `CLIENTMASTERDIR`: Directory path for the Clients root partition.
- `BOOTMASTERDIR`: Directory path for the TFTP boot partition.
- `OUTPUT_LINK`: Symbolic link for the output image.
- `GITHUB_URL`: URL for downloading necessary files from the Raspberry Pi firmware repository.
- `DEFAULT_USER`: Default username for the Raspberry Pi (prompted if not set).
- `DEFAULT_PASSWORD`: Default password for the Raspberry Pi (prompted if not set).

### Usage

1. Clone this repository to your Raspberry Pi or a suitable system.

2. Modify the `netboot-setup.sh` script's configuration settings as needed.

3. Run the script:

   ```bash
   ./getlatest.sh
   ```

4. Follow the prompts to provide the required information.

5. The script will download the latest Raspberry Pi OS Lite image, configure it, and prepare the netboot environment.

6. Once the script completes, you can use the created directories as master reference for adding clients.

## Raspberry Pi Netboot Client Setup (addclient.sh)

### Configuration

The `addclient.sh` script sets up a Raspberry Pi as a netboot client. Configure the following variables in the script:

- `CLIENT_NFS_DIRECTORY`: Directory path for the client's NFS root.
- `TFTP_DIRECTORY`: Directory path for the TFTP boot files.
- `CLIENT_MASTER`: Directory name for the client's master directory (if applicable).
- `TFTP_MASTER`: Directory name for the TFTP master directory (if applicable).
- `NFS_ROOT`: The NFS server's root path.
- `OWNER`: The owner of the created directories.
- `SSH_PUBKEY_PATH`: Path to your SSH public key (ensure it's available at this path).

### Usage

1. Clone this repository to your Raspberry Pi or a suitable system.

2. Make sure your SSH public key is available at the specified path (`SSH_PUBKEY_PATH`) in the script.

3. Run the `addclient.sh` script with the client's name as an argument:

   ```bash
   ./addclient.sh <client_name>
   ```

   Replace `<client_name>` with the serial number of the Raspberry Pi.

4. The script will create the necessary directories, update the boot configuration, set the client's hostname, configure NFS mounts, and enable SSH access.

5. You can now boot your Raspberry Pi with the netboot setup.

## Raspberry Pi Netboot Client Batch Setup (batch-addclients.sh)

The `batch-addclients.sh` script allows you to create multiple netboot clients using a list of serial numbers. Customize the `batch-addclients.sh` script and run it as follows:

```bash
./batch-addclients.sh <serial_numbers_file>
```

Replace `<serial_numbers_file>` with the path to a file containing a list of serial numbers, one per line. The script will create netboot clients for each serial number.

## Note

- These scripts are designed for use with Raspberry Pi netboot setups.

- Customize the scripts to match your network and server setup as needed.


