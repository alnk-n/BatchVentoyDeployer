#!/bin/bash

# Tips:
# To add a command alias, go into ~/.bashrc and under the #Aliases section add: alias clone-disks="sudo /path/to/your/Ventoy-Installer-Script.sh"

# Variables:
iso_src="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)/ISOs"
ventoy_archive_name="ventoy-1.1.07"
ventoy_script_src="./$ventoy_archive_name/Ventoy2Disk.sh"
marker_file="./.init-setup-marker.txt"

separator() {
  printf '%0.s-' {1..60}; echo
}

# Super-user check
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

# Initial setup check
# -------------------------------------------------------------------------
if [ ! -f "$marker_file" ]; then
  printf "★ Initial setup running..."

  apt update
  
  # Create ISO source folder
  if [ ! -d "$iso_src" ]; then
  mkdir "$iso_src"
  printf "★ Created ISO source folder @: %s\n" "$iso_src"
  printf "★ Place your ISO files in this directory.\n"
  else
  printf "★ ISO source folder exists @ %s. Continuing.\n" "$iso_src"
  fi

  # Install Zenity
  if apt install -y zenity; then
    printf "★ Zenity installed successfully.\n"
  else
    printf "★ Failed to install zenity. Exiting.\n"
    exit 1
  fi

  # Check for Curl installation
  if dpkg -l | grep -q "curl"; then
    printf "★ Curl is installed.\n"
  else
    printf "★ Curl is not installed. Downloading.\n"
        sudo apt-get update && sudo apt-get install curl
  fi

  # cURL Ventoy script and extract it from the archive
  if curl -L -O https://github.com/ventoy/Ventoy/releases/download/v1.1.07/ventoy-1.1.07-linux.tar.gz; then
    printf "★ Ventoy tarball downloaded successfully.\n"
    tar -xvzf ./$ventoy_archive_name; rm -f ./$ventoy_archive_name
    printf "★ Ventoy tarball extracted successfully.\n"
  else
    printf "★ Failed to download Ventoy tarball. Exiting.\n"
    exit 1
  fi

  touch "$marker_file"
fi

# Main script
# -------------------------------------------------------------------------
printf "\n\n\n"
printf "=== Ventoy USB Creator ===\n\n"
printf "This tool creates bootable Ventoy USB drives.\n"
printf "WARNING: This process is irreversible. The selected disks will be erased.\n\n"

# List disk names, model, size
printf "Detected disks:\n"
separator
lsblk --nodeps -o NAME,MODEL,SIZE | grep -v '^loop'
separator
echo

# Ask for disk selection
printf "(press Enter to exit)\n"
printf "Enter the disks you wish to format, separated by spaces (e.g. sdd sde sdf):\n"
read -r -p "> " choices

# Exit if no disks are selected
if [ -z "$choices" ]; then
  printf "No disks selected. Exiting.\n"
  exit 1
fi

# Copy ISOs to pendrives one by one
for choice in $choices; do
  device="/dev/$choice"

  # check for device
  if [ ! -b "$device" ]; then
    printf "Error: %s does not exist. Skipping.\n" "$device"
    continue
  fi

  echo
  printf "Formatting %s with Ventoy...\n" "$device"
  sleep 1

  # Try using Ventoy script
  printf 'y\ny\n' | "$ventoy_script_src" -I -s -g "$device" || {
    printf "Ventoy installation failed for %s. Skipping.\n" "$device"
    continue
  }

  # Create dynamic mount point using selected disk input
  ventoy_mnt="/mnt/ventoy_$choice"
  mkdir -p "$ventoy_mnt"

  echo
  printf "Mounting Ventoy data partition for %s...\n" "$device"
  sleep 1

  # Wait for kernel to settle partition table and labels before probing
  udevadm settle --timeout=10
  sleep 2

  # Fetch path to main Ventoy parition on specified drive
  ventoy_part=$(lsblk -o NAME,LABEL -nr "$device" | awk '$2=="Ventoy"{print "/dev/" $1}')

  # Check for main Ventoy partition
  if [ -z "$ventoy_part" ]; then
    printf "Could not find Ventoy partition on %s. Skipping.\n" "$device"
    continue
  fi

  # Try to mount main Ventoy partition
  mount "$ventoy_part" "$ventoy_mnt" || {
    printf "Failed to mount %s to %s. Skipping.\n" "$ventoy_part" "$ventoy_mnt"
    continue
  }

  # Give anyone write permissions to the Ventoy partition
  chmod -R 777 "$ventoy_mnt" || {
    printf "Failed to change permissions (chmod couldn't change the permissions of the main partition). Skipping.\n"
    continue
  }

  echo
  printf "Copying ISO files from %s to %s ...\n" "$iso_src" "$ventoy_mnt"
  
  # try to copy all ISO files from source folder to mounted partition
  rsync "$iso_src/"*.iso "$ventoy_mnt"/ -v -h --progress || {
    printf "Failed to copy ISO files to %s.\n" "$device"
    umount "$ventoy_mnt"
    continue
  }

  echo
  printf "Unmounting %s...\n" "$ventoy_mnt"

  # Unmount main Ventoy partition and delete temporary mount point
  umount "$ventoy_mnt"
  rmdir "$ventoy_mnt"

  echo
  printf "Ventoy USB on %s is ready!\n" "$device"
done

echo
printf "All selected USB drives have been processed.\n"
