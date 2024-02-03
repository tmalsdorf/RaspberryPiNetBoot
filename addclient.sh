#!/bin/bash

# Configuration variables
CLIENT_NFS_DIRECTORY="/data/clients/"
TFTP_DIRECTORY="/data/tftp/"
CLIENT_MASTER="raspios-lite/"
TFTP_MASTER="bootmaster/"
NFS_ROOT="192.168.1.20"
OWNER="pi"
SSH_PUBKEY_PATH="pubkey"  # Add the correct path to your SSH public key

# Function for error handling
handle_error() {
    local error_message=$1
    echo "Error: $error_message"
    exit 1
}

# Function to check command dependencies
check_dependency() {
    local dependency=$1
    if ! command -v "$dependency" &> /dev/null; then
        handle_error "Command not found: $dependency"
    fi
}

# Function to create and setup directories
setup_directory() {
    local dir_path=$1
    local owner=$2
    local master_dir=$3

    if [ -d "$dir_path" ]; then
        echo "Directory exists, removing: $dir_path"
        rm -rf "$dir_path" || handle_error "Failed to remove directory: $dir_path"
    fi

    echo "Creating directory: $dir_path"
    mkdir -p "$dir_path" || handle_error "Failed to create directory: $dir_path"
    #chown "$owner:" "$dir_path" || handle_error "Failed to set ownership for directory: $dir_path"

    if [ -n "$master_dir" ]; then
        echo "Copying contents from $master_dir to $dir_path"
        rsync -zah "$master_dir" "$dir_path/" || handle_error "Failed to copy contents to $dir_path"
    fi
}

# Function to update boot cmdline
update_boot_cmdline() {
    local dir_path=$1
    local cmdline="dwc_otg.lpm_enable=0 console=serial0,115200 console=tty root=/dev/nfs nfsroot=$NFS_ROOT:/volume1/clients/$client_name,vers=3 rw ip=dhcp rootwait elevator=deadline cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory"
    echo "$cmdline" > "$dir_path/cmdline.txt" || handle_error "Failed to update boot cmdline in $dir_path"
}

# Function to setup SSH
setup_ssh() {
    local ssh_dir="$1/home/pi/.ssh"
    if [ ! -d "$ssh_dir" ]; then
        echo "Creating SSH directory: $ssh_dir"
        mkdir -p "$ssh_dir" || handle_error "Failed to create SSH directory: $ssh_dir"
    fi

    echo "Setting up SSH public key"
    cat "$SSH_PUBKEY_PATH" > "$ssh_dir/authorized_keys" || handle_error "Failed to copy SSH public key"
    chmod 644 "$ssh_dir/authorized_keys" || handle_error "Failed to set permissions for authorized_keys"
    chown 1000:1000 "$ssh_dir/authorized_keys" || handle_error "Failed to set ownership for authorized_keys"
}

# Function to update fstab
update_fstab() {
    local nfs_path=$1
    local fstab_path="$nfs_path/etc/fstab"
    local nfs_mount="$NFS_ROOT:/volume1/clients/$client_name / nfs defaults 0 0"
    local boot_mount="$NFS_ROOT:/volume1/tftp/$client_name /boot nfs defaults 0 0"

    echo "Updating fstab in $fstab_path"

    # Remove any lines starting with "PARTUUID"
    sed -i '/^PARTUUID/d' "$fstab_path" || handle_error "Failed to remove PARTUUID lines from $fstab_path"

    # Append the new NFS mount configuration
    echo "$nfs_mount" >> "$fstab_path" || handle_error "Failed to update fstab in $fstab_path"

    # Append the new boot mount configuration
    echo "$boot_mount" >> "$fstab_path" || handle_error "Failed to update fstab in $fstab_path"
}

# Main script starts here
# Check command line dependencies
check_dependency rsync
check_dependency chown

# Check for the correct number of arguments
if [ $# -ne 1 ]; then
    handle_error "Usage: $0 <client_name>"
fi

client_name=$1
client_nfs_path="${CLIENT_NFS_DIRECTORY}${client_name}"
tftp_path="${TFTP_DIRECTORY}${client_name}"

# Setup NFS and TFTP directories
setup_directory "$client_nfs_path" "$OWNER" "${CLIENT_NFS_DIRECTORY}${CLIENT_MASTER}"
setup_directory "$tftp_path" "$OWNER" "${TFTP_DIRECTORY}${TFTP_MASTER}"

# Update boot cmdline
update_boot_cmdline "$client_nfs_path/boot"
update_boot_cmdline "$tftp_path"

# Set client hostname
echo "$client_name" > "$client_nfs_path/etc/hostname" || handle_error "Failed to set hostname"

# Set permissions and enable SSH
chmod 755 "$client_nfs_path"

# Update fstab
update_fstab "$client_nfs_path"

# Setup SSH
#setup_ssh "$client_nfs_path"

echo "Client $client_name added successfully."
