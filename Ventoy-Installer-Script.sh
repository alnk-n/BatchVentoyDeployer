#!/bin/bash

# Dependencies:
# - Ventoy script from (https://www.ventoy.net/en/download.html)

# Tips:
# To add a command alias, go into ~/.bashrc and under the #Aliases section add: alias clone-disks="sudo /path/to/your/Ventoy-Installer-Script.sh"

# Variables:
iso_src="$HOME/ISOs"
ventoy_script_src="./ventoy-1.1.07/Ventoy2Disk.sh"
marker_file="./.init-setup-marker.txt"

separator() {
  printf '%*s\n' 60 | tr ' ' '-'
}

# Super-user check
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Exiting."
  exit 1
fi

# Initial setup check
# -------------------------------------------------------------------------
if [ ! -f "$marker_file" ]; then
  printf "Initial setup running..."

  apt update
  
  # Create ISO source folder
  if [ ! -d "$iso_src" ]; then
  mkdir "$iso_src"
  printf "- Created ISO source folder @: $iso_src"
  printf "- Place your ISO files in this directory."
  else
  printf "- ISO source folder exists @ $iso_src. Continuing."
  fi

  # Install Zenity
  if apt install -y zenity; then
    printf "- Zenity installed successfully."
  else
    printf "- Failed to install zenity. Exiting."
    exit 1
  fi

  # Check for Curl installation
  if dpkg -l | grep -q "curl"; then
    printf "- Curl is installed."
  else
    printf "- Curl is not installed. Downloading."
        sudo apt-get update && sudo apt-get install curl
  fi

  # cURL Ventoy script and extract it from the archive
  if curl -i https://github.com/ventoy/Ventoy/releases/download/v1.1.07/ventoy-1.1.07-linux.tar.gz -O; then
    printf "- Ventoy tarball downloaded successfully."
    tar -xvzf ./ventoy-1.1.07.tar.gz; rm -f ./ventoy-1.1.07.tar.gz
    printf "- Ventoy tarball extracted successfully."   
  else
    printf "- Failed to download Ventoy tarball. Exiting."
    exit 1
  fi

  touch "$marker_file"
fi

# Main script
# -------------------------------------------------------------------------
printf '%*s\n' 60 | tr ' ' '\n'
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
read -p "> " choices

# Exit if no disks are selected
if [ -z "$choices" ]; then
  printf "No disks selected. Exiting."
  exit 1
fi

# Copy ISOs to pendrives one by one
for choice in $choices; do
  device="/dev/$choice"

  # check for device
  if [ ! -b "$device" ]; then
    printf "Error: $device does not exist. Skipping."
    continue
  fi

  echo
  printf "Formatting $device with Ventoy...\n"
  sleep 1

  # Try using Ventoy script
  "$ventoy_script_src" -I -s -g "$device" || {
    printf "Ventoy installation failed for $device. Skipping."
    continue
  }

  # Create dynamic mount point using selected disk input
  ventoy_mnt="/mnt/ventoy_$choice"
  mkdir -p "$ventoy_mnt"

  echo
  printf "Mounting Ventoy data partition for $device...\n"
  sleep 1

  # Fetch path to main Ventoy parition on specified drive
  ventoy_part=$(lsblk -o NAME,LABEL -nr "$device" | awk '$2=="Ventoy"{print "/dev/" $1}')

  # Check for main Ventoy partition
  if [ -z "$ventoy_part" ]; then
    printf "Could not find Ventoy partition on $device. Skipping."
    continue
  fi

  # Try to mount main Ventoy partition
  mount "$ventoy_part" "$ventoy_mnt" || {
    printf "Failed to mount $ventoy_part to $ventoy_mnt. Skipping."
    continue
  }

  # Give anyone write permissions to the Ventoy partition
  chmod -R 777 "$ventoy_mnt" || {
    printf "Failed to change permissions (chmod couldn't change the permissions of the main partition). Skipping."
    continue
  }

  echo
  printf "Copying ISO files from $iso_src to $ventoy_mnt ...\n"
  
  # try to copy all ISO files from source folder to mounted partition
  rsync "$iso_src/"*.iso "$ventoy_mnt"/ -v -h --progress || {
    printf "Failed to copy ISO files to $device."
    umount "$ventoy_mnt"
    continue
  }

  echo
  printf "Unmounting $ventoy_mnt...\n"

  # Unmount main Ventoy partition and delete temporary mount point
  umount "$ventoy_mnt"
  rmdir "$ventoy_mnt"

  echo
  printf "Ventoy USB on $device is ready!\n"
done

echo
printf "All selected USB drives have been processed.\n"