#!/bin/bash
# All UI output and input prompts.
# Sourced by ventoy-creator.sh, do not run directly.

separator() {
  printf '%0.s-' {1..60}; echo
}

ui_header() {
  printf "\n\n"
  printf "=== Batch Ventoy Deployer ===\n\n"
  printf "Tool used for mass-deploying bootable Ventoy USB drives.\n"
  printf "Built on the Ventoy2Disk CLI (https://github.com/ventoy/Ventoy) and ♥︎\n\n"
}

ui_list_disks() {
  printf "Detected disks:\n"
  separator
  lsblk --nodeps -o NAME,MODEL,SIZE | grep -v '^loop'
  separator
  echo
}
 
ui_prompt_disk_selection() {
  printf "(press Enter to exit)\n"
  printf "Enter the disks you wish to format, separated by spaces (e.g. sdd sde sdf):\n"
  read -r -p "> " DISK_CHOICES
  export DISK_CHOICES
}
 
ui_confirm_selection() {
  local devices=("$@")

  printf "\nThe following disks will be erased and formatted:\n\n"
  for device in "${devices[@]}"; do
    local model size
    model=$(lsblk --nodeps -no MODEL "$device" 2>/dev/null | xargs)
    size=$(lsblk --nodeps -no SIZE "$device" 2>/dev/null | xargs)
    printf "  %s ・ %s %s\n" "$device" "$model" "$size"
  done

  printf "\nThis will destroy all data on the above disks.\n"
  printf "The process will then run unattended until complete.\n\n"
  read -r -p "Confirm and proceed? [y/N] > " confirm
  case "$confirm" in
    [yY]) return 0 ;;
    *)    return 1 ;;
  esac
}
 
ui_msg()     { printf "%s\n" "$1"; }
ui_success() { printf "✔ %s\n" "$1"; }
ui_warn()    { printf "⚠ %s\n" "$1"; }
ui_error()   { printf "✘ %s\n" "$1" >&2; }