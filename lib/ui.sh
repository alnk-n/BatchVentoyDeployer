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
  printf "Built on the Ventoy2Disk CLI (https://github.com/ventoy/Ventoy) and ❤️ .\n\n"
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
 
ui_confirm_device() {
  local device="$1"
  local model size
  model=$(lsblk --nodeps -no MODEL "$device" 2>/dev/null | xargs)
  size=$(lsblk --nodeps -no SIZE "$device" 2>/dev/null | xargs)
  printf "\nAbout to erase %s (%s %s).\n" "$device" "$model" "$size"
  read -r -p "Are you sure? [y/N] > " confirm
  case "$confirm" in
    [yY]) return 0 ;;
    *)    return 1 ;;
  esac
}
 
ui_msg()     { printf "%s\n" "$1"; }
ui_success() { printf "✔ %s\n" "$1"; }
ui_warn()    { printf "⚠ %s\n" "$1"; }
ui_error()   { printf "✘ %s\n" "$1" >&2; }
 
# # --- Quick UI Test (remove before production) ---
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     ui_header
#     ui_list_disks
#     ui_prompt_disk_selection
#     ui_msg     "Processing your selection: $DISK_CHOICES"
#     ui_confirm_device "/dev/sda"
#     ui_success "Device confirmed and formatted successfully."
#     ui_warn    "This device has an existing Ventoy installation — it will be overwritten."
#     ui_error   "Failed to write to device: permission denied."
# fi