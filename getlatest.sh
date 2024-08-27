#!/bin/bash

# Source environment variables
source env.sh || { echo "Could not load environment file"; exit 1; }

# Check for required tools
check_dependency() {
    local dependency=$1
    if ! command -v "$dependency" &> /dev/null; then
        echo "$dependency is not installed. Please install it to use this script."
        exit 1
    fi
}

# Get the latest version directory
get_latest_version_dir() {
    local version_dir
    version_dir=$(curl -s "$BASE_URL" | grep -oP 'raspios_lite_arm64-\d{4}-\d{2}-\d{2}/' | sort -V | tail -n 1)
    version_dir="${version_dir%/}"  # Trim the trailing slash
    echo "$version_dir"
}

# Function to prompt for a username
prompt_for_username() {
    read -p "Enter username: " user_name
    echo "$user_name"
}

# Function to prompt for a password and encrypt it
prompt_for_password() {
    read -s -p "Enter password: " user_password
    echo
    encrypted_password=$(openssl passwd -6 "$user_password")
    echo "$encrypted_password"
}

# Function to prompt for BOOTMASTERDIR
prompt_for_bootmasterdir() {
    read -p "Enter Directory path for TFTP boot partition: " BOOTMASTERDIR
    echo "$BOOTMASTERDIR"
}

# Function to prompt for CLIENTMASTERDIR
prompt_for_clientmasterdir() {
    read -p "Enter Directory path for Clients root partition: " CLIENTMASTERDIR
    echo "$CLIENTMASTERDIR"
}
# Download a file if it doesn't already exist
download_file() {
    local url=$1
    local destination=$2
    if [ ! -f "$destination" ]; then
        curl -O "$url"
        echo "Downloaded $destination"
    else
        echo "The file $destination already exists. No download needed."
    fi
}

# Extract a file if not already extracted
extract_file() {
    local file=$1
    local base_filename="${file%%.img.xz}"
    if [ ! -f "$base_filename.img" ]; then
        unxz -k "$file" || { echo "Error: Image extraction failed."; exit 1; }
        echo "Extracted $file"
    else
        echo "The image file $base_filename.img already exists. No extraction needed."
    fi
}

# Setup or clear the temporary image directory
setup_tmpimg_dir() {
    if [ -d "$TMPIMG_DIR" ]; then
        rm -rf "$TMPIMG_DIR"/*
        echo "Cleared $TMPIMG_DIR directory."
    else
        mkdir "$TMPIMG_DIR"
        echo "Created $TMPIMG_DIR directory."
    fi
}

# Create device mappings for the image file
create_mappings() {
    local img_file=$1
    kpartx_output=$(kpartx -av "$img_file" | awk '{print $3}')
    if [ -z "$kpartx_output" ]; then
        echo "Error: Failed to create mappings."
        exit 1
    fi
    echo "$kpartx_output"
}

# Mount the partitions
mount_partitions() {
    local mount_points=$1
    for mount_point in $mount_points; do
        if [ ! -d "$TMPIMG_DIR/$mount_point" ]; then
            mkdir -p "$TMPIMG_DIR/$mount_point"
        fi
        mount "/dev/mapper/$mount_point" "$TMPIMG_DIR/$mount_point" || { echo "Error mounting $mount_point"; exit 1; }
        echo "Mounted /dev/mapper/$mount_point to $TMPIMG_DIR/$mount_point"
    done
}

# Identify the boot and root partitions
identify_partitions() {
    local mount_points=$1
    local boot_partition=""
    local root_partition=""
    for mount_point in $mount_points; do
        if [ -f "$TMPIMG_DIR/$mount_point/config.txt" ]; then
            boot_partition="$TMPIMG_DIR/$mount_point"
        fi
        if [ -d "$TMPIMG_DIR/$mount_point/boot" ]; then
            root_partition="$TMPIMG_DIR/$mount_point"
        fi
    done
    if [ -z "$boot_partition" ] || [ -z "$root_partition" ]; then
        echo "Error: Boot or Root partition not found."
        exit 1
    fi
    echo "$boot_partition $root_partition"
}

# Copy contents from source to destination
copy_partition_contents() {
    local source=$1
    local destination=$2
    rsync -zah "$source/" "$destination/" || { echo "Error copying from $source to $destination"; exit 1; }
    echo "Copied $source contents to $destination"
}

# Unmount partitions and cleanup
unmount_and_cleanup() {
    local mount_points=$1
    for mount_point in $mount_points; do
        umount "$TMPIMG_DIR/$mount_point" || { echo "Warning: Failed to unmount $mount_point"; }
    done
    kpartx -dv "$base_filename.img"
    rm -rf "$TMPIMG_DIR"
    echo "Cleaned up mounted directories"
    rm "$base_filename.img"
    echo "Cleaned up temporary image file"
}

# Function to create an empty ssh file
create_ssh_file() {
    local boot_path=$1
    local ssh_file_path="$boot_path/ssh"

    echo "Creating empty SSH file in $boot_path"
    touch "$ssh_file_path" || handle_error "Failed to create SSH file in $boot_path"
    chmod 755 "$ssh_file_path"
}

# Function to add first-boot script
# added because boot filesystem is not a seprate filesystem when we netboot
ssh_startup_mod_script() {
    local boot_path=$1
    local first_boot_script_path="$boot_path/usr/lib/raspberrypi-sys-mods/sshswitch"

    # Create the first-boot script
    cat > "$first_boot_script_path" << 'EOF'
#!/bin/sh

set -e

FOUND=0
for file in "/boot/ssh" "/boot/ssh.txt"; do
  [ -e "$file" ] || continue
  FOUND=1
  #rm -f "$file"
done

if [ "$FOUND" = "1" ]; then
  systemctl enable --now --no-block ssh
fi

exit 0
EOF

    # Make the script executable
    chmod +x "$first_boot_script_path"
    echo "Modded ssh enable script"
}


# Update netboot files
update_netboot_files() {
    local directory=$1
    rm "$directory/start4.elf" "$directory/fixup4.dat"
    wget "$GITHUB_URL/start4.elf" -P "$directory/"
    chmod 755 "$directory/start4.elf"  || handle_error "Failed to set permissions for netboot files"
    wget "$GITHUB_URL/fixup4.dat" -P "$directory/"
    chmod 755 "$directory/fixup4.dat" || handle_error "Failed to set permissions for netboot files"
    echo "Updated netboot files in $directory"
}

# Function to create userconfig.txt
create_userconfig() {
    local boot_path=$1
    local username=$2
    local password=$3
    local userconfig_path="$boot_path/userconf"

    echo "Creating userconfig in $boot_path"
    echo "$username:$password" > "$userconfig_path" || handle_error "Failed to create userconf"
    chmod 755 "$userconfig_path" || handle_error "Failed to set permissions for userconf"

}


# Main script execution
check_dependency "curl"
check_dependency "kpartx"
check_dependency "rsync"
check_dependency "wget"
check_dependency "openssl"

# move to CLIENTMASTERDIR
cd $CLIENTMASTERDIR || handle_error "Failed to change directory to CLIENTMASTERDIR"

# Check if DEFAULT_USER is set, if not, prompt for it
if [ -z "$DEFAULT_USER" ]; then
    echo "DEFAULT_USER is not set. Please enter a username."
    DEFAULT_USER=$(prompt_for_username)
fi

# Check if DEFAULT_PASSWORD is set, if not, prompt for it
if [ -z "$DEFAULT_PASSWORD" ]; then
    echo "DEFAULT_PASSWORD is not set. Please enter a password."
    DEFAULT_PASSWORD=$(prompt_for_password)
fi

# Check if BOOTMASTERDIR is set, if not, prompt for it
if [ -z "$BOOTMASTERDIR" ]; then
    echo "BOOTMASTERDIR is not set. Please enter the Boot Master Directory path."
    BOOTMASTERDIR=$(prompt_for_bootmasterdir)
fi


echo "Base URL: $BASE_URL"
latest_version_dir=$(get_latest_version_dir)
echo "Latest version directory: $latest_version_dir"

download_url="${BASE_URL}${latest_version_dir}/"
echo "Download URL: $download_url"

image_file=$(curl -s "$download_url" | grep -oP '(?<=href=")[^"]*\.img\.xz' | head -n 1)
echo "Image file: $image_file"

full_url="${download_url}${image_file}"
echo "Full URL: $full_url"

base_filename="${image_file%%.img.xz}"
echo "Base filename: $base_filename"

download_file "$full_url" "$image_file"
extract_file "$image_file"

setup_tmpimg_dir

kpartx_output=$(create_mappings "$base_filename.img")
mount_partitions "$kpartx_output"
partitions=$(identify_partitions "$kpartx_output")
read -r boot_partition root_partition <<< "$partitions"

# Check if the output directory already exists
if [ -d "$base_filename" ]; then
    echo "The output directory $base_filename already exists. Cleaning up old files..."
    rm -rf "$base_filename"
    echo "Removed output directory: $base_filename"
fi

if [ -d "$BOOTMASTERDIR/$base_filename-boot" ]; then
    echo "The output directory $BOOTMASTERDIR/$base_filename-boot already exists. Cleaning up old files..."
    rm -rf "$BOOTMASTERDIR/$base_filename-boot"
    echo "Removed output directory: $BOOTMASTERDIR/$base_filename-boot"
fi

if [ ! -d "$base_filename" ]; then
    mkdir "$base_filename"
    echo "Created output directory: $base_filename"
fi

if [ ! -d "$BOOTMASTERDIR/$base_filename-boot" ]; then
    mkdir "$BOOTMASTERDIR/$base_filename-boot"
    echo "Created output directory: $BOOTMASTERDIR/$base_filename-boot"
fi

# Copy root partition contents
echo "Copying root partition contents... $root_partition to $base_filename"
copy_partition_contents "$root_partition" "$base_filename"
# Copy boot partition contents
echo "Copying boot partition contents... $boot_partition to $BOOTMASTERDIR/$base_filename-boot"
copy_partition_contents "$boot_partition" "$BOOTMASTERDIR/$base_filename-boot"

unmount_and_cleanup "$kpartx_output"

create_ssh_file "$BOOTMASTERDIR/$base_filename-boot"
create_ssh_file "$CLIENTMASTERDIR/$base_filename/boot"

create_userconfig "$CLIENTMASTERDIR/$base_filename/boot" "$DEFAULT_USER" "$DEFAULT_PASSWORD"
create_userconfig "$BOOTMASTERDIR/$base_filename-boot"  "$DEFAULT_USER" "$DEFAULT_PASSWORD"

ssh_startup_mod_script "$base_filename"

# Symbolic link management
if [ -L "$OUTPUT_LINK" ]; then
    unlink "$OUTPUT_LINK"
    echo "Unlinked old base image"
fi
ln -s "$base_filename" "$OUTPUT_LINK"
echo "Linked new base image as $OUTPUT_LINK"

#update_netboot_files "$BOOTMASTERDIR/$base_filename-boot"

ssh_startup_mod_script "$base_filename"

echo "Done!"

#synology tftp specific
#copy_partition_contents "$base_filename/boot" "$BOOTMASTERDIR/$base_filename-boot"
# bootmaster Symbolic link management
if [ -L "$BOOTMASTERDIR/bootmaster" ]; then
    unlink "$BOOTMASTERDIR/bootmaster"
    echo "Unlinked old bootmaster image"
fi

# move into bootmaster directory
cd $BOOTMASTERDIR
ln -s "$base_filename-boot" "bootmaster"
echo "Linked new bootmaster image as $BOOTMASTERDIR/bootmaster"

# move to previous directory
cd -

# move to original directory
cd -

