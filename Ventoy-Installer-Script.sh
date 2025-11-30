#!/bin/bash

# Dependencies:
# - Ventoy script from (https://www.ventoy.net/en/download.html)

# Tips:
# To add a command alias, go into ~/.bashrc and under the #Aliases section add: alias clone-disks="sudo /path/to/your/Ventoy-Installer-Script.sh"

# Variables:
iso_src="/home/usbcs/ISOs"
ventoy_script_src="/home/usbcs/ventoy-1.1.07/Ventoy2Disk.sh"

separator() {
  printf '%*s\n' 60 | tr ' ' '-'
}

printf '%*s\n' 60 | tr ' ' '\n'
printf "=== Ventoy USB Creator ===\n\n"
printf "This tool creates bootable Ventoy USB drives.\n"
printf "WARNING: This process is irreversible. The selected disks will be erased.\n\n"

# list disk names, model
printf "Detected disks:\n"
separator
lsblk --nodeps -o NAME,MODEL,SIZE | grep -v '^loop'
separator
echo

# ask for disk choices
printf "(press Enter to exit)\n"
printf "Enter the disks you wish to format, separated by spaces (e.g. sdd sde sdf):\n"
read -p "> " choices

# exit if no disks are selected
if [ -z "$choices" ]; then
  printf "No disks selected. Exiting."
  exit 1
fi

# check if ISO source folder exists
if [ ! -d "$iso_src" ]; then
  printf "ISO source folder not found: $iso_src"
  printf "Create that directory and place your ISO files in there."
  exit 1
fi

# main script
for choice in $choices; do
  device="/dev/$choice"

  # check for device
  if [ ! -b "$device" ]; then
    printf "Error: $device does not exist. Skipping."
    continue
  fi

  echo
  printf "Installing Ventoy on $device...\n"
  sleep 1

  # try ventoy script
  sudo "$ventoy_script_src" -I -s -g "$device" || {
    printf "Ventoy installation failed for $device. Skipping."
    continue
  }

  # make dynamic mount point using selected disk input
  ventoy_mnt="/mnt/ventoy_$choice"
  sudo mkdir -p "$ventoy_mnt"

  echo
  printf "Mounting Ventoy data partition for $device...\n"
  sleep 1

  # outputs path to main ventoy parition on specified drive
  ventoy_part=$(lsblk -o NAME,LABEL -nr "$device" | awk '$2=="Ventoy"{print "/dev/" $1}')

  # check for main ventoy partition
  if [ -z "$ventoy_part" ]; then
    printf "Could not find Ventoy partition on $device. Skipping."
    continue
  fi

  # try to mount Ventoy partition
  sudo mount "$ventoy_part" "$ventoy_mnt" || {
    printf "Failed to mount $ventoy_part to $ventoy_mnt. Skipping."
    continue
  }

  # try to change permissions so anyone can write to the Ventoy partition
  sudo chmod -R 777 "$ventoy_mnt" || {
    printf "Failed to change permissions (chmod couldn't change the permissions of the main partition). Skipping."
    continue
  }

  echo
  printf "Copying ISO files from $iso_src to $ventoy_mnt ...\n"
  
  # try to copy all ISO files from source folder to mounted partition
  rsync "$iso_src/"*.iso "$ventoy_mnt"/ -v -h --progress || {
    printf "Failed to copy ISO files to $device."
    sudo umount "$ventoy_mnt"
    continue
  }

  echo
  printf "Unmounting $ventoy_mnt...\n"

  # unmount ventoy partition and remove temporary mount point
  sudo umount "$ventoy_mnt"
  sudo rmdir "$ventoy_mnt"

  echo
  printf "Ventoy USB on $device is ready!\n"
done

echo
printf "All selected USB drives have been processed.\n"
