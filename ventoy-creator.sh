#!/bin/bash
# BatchVentoyDeployer — batch Ventoy USB creator
# Usage: sudo <summon_command> [--help|--update]

set -uo pipefail

BVD_DATA="/usr/local/share/batchventoydeployer"

source "$BVD_DATA/config/defaults.conf"
source "$BVD_DATA/lib/ui.sh"
source "$BVD_DATA/lib/disk.sh"
source "$BVD_DATA/lib/ventoy.sh"

# Logging: tee all output to log file
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

# Flag handling
case "${1:-}" in
  --update)
    exec sudo "/usr/local/share/$APP_NAME/install.sh" --update
    ;;
  --help|-h)
    printf "Usage: sudo %s [--help|--update]\n\n" "$SUMMON_COMMAND"
    printf "What this tool does:\n"
    printf "  Formats USB drives with Ventoy and copies ISO files onto them.\n"
    printf "  Select your drives, confirm once — it handles the rest unattended.\n\n"
    printf "Options:\n"
    printf "  --help, -h    Show this message and exit\n"
    printf "  --update      Re-download and reinstall Ventoy (run after a version change)\n\n"
    printf "Before running:\n"
    printf "  Place your .iso files in: %s\n\n" "$ISO_SRC"
    printf "Configuration (managed by your admin):\n"
    printf "  Ventoy version : %s\n" "$VENTOY_VERSION"
    printf "  ISO source     : %s\n" "$ISO_SRC"
    printf "  Log file       : %s\n" "$LOG_FILE"
    printf "  Config file    : /usr/local/share/%s/config/defaults.conf\n\n" "$APP_NAME"
    printf "  To change settings, open the config file as root:\n"
    printf "  sudo nano /usr/local/share/%s/config/defaults.conf\n" "$APP_NAME"
    exit 0
    ;;
esac

# Superuser check
if [ "$(id -u)" -ne 0 ]; then
  ui_error "This script must be run as root. Try: sudo $SUMMON_COMMAND"
  exit 1
fi

# Setup check
if [ ! -f "$MARKER_FILE" ] || [ "$(sed -n '1p' "$MARKER_FILE" 2>/dev/null || true)" != "$VENTOY_VERSION" ]; then
  ui_warn "Setup not complete or Ventoy version changed. Please run: sudo ./install.sh"
  exit 1
fi

# Array of active mount points tracked for trap cleanup
active_mnts=()

# Trap: signal the whole process group then clean up any registered mounts
trap '
  ui_warn "Interrupted. Cleaning up..."
  kill -- -$$ 2>/dev/null || true
  for _mnt in "${active_mnts[@]:-}"; do
    if mountpoint -q "$_mnt" 2>/dev/null; then
      umount "$_mnt" 2>/dev/null
      rmdir "$_mnt" 2>/dev/null
    fi
  done
  rm -rf "${BVD_STATUS_DIR:-}" 2>/dev/null || true
  tput cnorm 2>/dev/null || true
  exit 1
' INT TERM

# Draws a fixed-width ASCII progress bar for a 0-100 percentage value.
_draw_progress_bar() {
  local pct=$1 width=20 filled empty bar i
  filled=$(( pct * width / 100 ))
  empty=$(( width - filled ))
  bar="["
  for (( i = 0; i < filled; i++ )); do bar+="█"; done
  for (( i = 0; i < empty;  i++ )); do bar+="░"; done
  bar+="]"
  printf "%s" "$bar"
}

# Renders a live per-drive progress table by redrawing N lines in-place.
# Reads per-drive status files from $1 (dir); remaining args are drive names.
# Writes directly to /dev/tty so the log file is not polluted with ANSI codes.
# Exits cleanly when $sdir/.done appears.
_progress_renderer() {
  local sdir="$1"; shift
  local choices=("$@")
  local n=${#choices[@]} frame=0
  local sp='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  exec > /dev/tty 2>&1
  tput civis 2>/dev/null || true
  for (( i = 0; i < n; i++ )); do printf "\n"; done
  while true; do
    printf "\033[%dA" "$n"
    local sf="${sp:$(( frame % ${#sp} )):1}"
    frame=$(( frame + 1 ))
    local c status stage pct label
    for c in "${choices[@]}"; do
      status=$(cat "$sdir/$c" 2>/dev/null || echo "waiting:0")
      stage="${status%%:*}"
      pct="${status#*:}"
      case "$stage" in
        waiting)    label="  Waiting..." ;;
        ventoy)     label="$sf Formatting with Ventoy" ;;
        settling)   label="$sf Waiting for kernel..." ;;
        mounting)   label="$sf Mounting..." ;;
        checking)   label="$sf Checking free space..." ;;
        copying)    label="$(_draw_progress_bar "$pct") ${pct}%  Copying ISOs" ;;
        unmounting) label="$sf Unmounting..." ;;
        done)       label="$(_draw_progress_bar 100) 100%  ✔ Done" ;;
        error)      label="  ✘ Failed" ;;
        *)          label="$sf ..." ;;
      esac
      printf "\033[2K  /dev/%-4s  %s\n" "$c" "$label"
    done
    [ -f "$sdir/.done" ] && break
    sleep 0.2
  done
  tput cnorm 2>/dev/null || true
}

# Installs Ventoy on one drive, mounts the data partition, copies ISOs, unmounts.
# Returns 0 on success, 1 on any failure.
process_drive() {
  local choice="$1"
  local sf="$BVD_STATUS_DIR/$choice"
  local device="/dev/$choice"
  local mnt="/mnt/ventoy_$choice"

  printf "ventoy:0" > "$sf"
  printf "\n[Processing] %s\n" "$device"

  ui_msg "Formatting $device with Ventoy..."
  if ! ventoy_install_to "$device"; then
    printf "error:0" > "$sf"
    ui_error "Ventoy installation failed for $device."
    return 1
  fi

  # Wait for the kernel to re-read the new GPT written by Ventoy
  printf "settling:0" > "$sf"
  udevadm settle --timeout=10
  sleep 2

  printf "mounting:0" > "$sf"
  local ventoy_part
  ventoy_part=$(disk_get_ventoy_part "$device")
  if [ -z "$ventoy_part" ]; then
    printf "error:0" > "$sf"
    ui_error "Could not find Ventoy partition on $device."
    return 1
  fi

  if ! disk_mount "$ventoy_part" "$mnt"; then
    printf "error:0" > "$sf"
    ui_error "Failed to mount $ventoy_part."
    return 1
  fi
  active_mnts+=("$mnt")

  printf "checking:0" > "$sf"
  local required
  required=$(disk_iso_total_size "$ISO_SRC")
  if ! disk_has_space "$mnt" "$required"; then
    printf "error:0" > "$sf"
    ui_error "Not enough space on $device for all ISOs."
    disk_unmount "$mnt"
    return 1
  fi

  printf "copying:0" > "$sf"
  ui_msg "Copying ISOs from $ISO_SRC to $mnt..."
  if ! disk_copy_isos "$ISO_SRC" "$mnt" "$sf"; then
    printf "error:0" > "$sf"
    ui_error "Failed to copy ISOs to $device."
    disk_unmount "$mnt"
    return 1
  fi

  printf "unmounting:0" > "$sf"
  disk_unmount "$mnt"
  printf "done:100" > "$sf"
  ui_success "$device is ready."
}

# Early ISO check, abort before touching any disks
iso_count=$(find "$ISO_SRC" -maxdepth 1 -name "*.iso" 2>/dev/null | wc -l)
if [ "$iso_count" -eq 0 ]; then
  ui_error "No ISO files found in $ISO_SRC. Add ISOs before running."
  exit 1
fi

# UI
ui_header
ui_list_disks
ui_prompt_disk_selection

if [ -z "$DISK_CHOICES" ]; then
  ui_msg "No disks selected. Exiting."
  exit 0
fi

# Validate all inputs up front before touching any disk
validated_choices=""
for choice in $DISK_CHOICES; do
  device="/dev/$choice"

  if ! disk_exists "$device"; then
    ui_error "$device does not exist or is not a block device. Skipping."
    continue
  fi

  if disk_is_system_disk "$device"; then
    ui_error "$device appears to be the system disk. Skipping."
    continue
  fi

  validated_choices="$validated_choices $choice"
done

validated_choices="${validated_choices# }"

if [ -z "$validated_choices" ]; then
  ui_error "No valid disks remaining after validation. Exiting."
  exit 1
fi

# Build device array and show single upfront confirmation
validated_devices=()
for choice in $validated_choices; do
  validated_devices+=("/dev/$choice")
done

if ! ui_confirm_selection "${validated_devices[@]}"; then
  ui_msg "Aborted."
  exit 0
fi

# Set up per-drive status files for the progress renderer
BVD_STATUS_DIR=$(mktemp -d /tmp/bvd_status_XXXXXX)
read -ra _choices_arr <<< "$validated_choices"
for choice in "${_choices_arr[@]}"; do
  printf "waiting:0" > "$BVD_STATUS_DIR/$choice"
done

# Fan-out: launch all drives in parallel, capturing output per drive
declare -A drive_pids
declare -A drive_logs

# Start live progress display if we have a terminal to write to
RENDERER_PID=""
if [ -w /dev/tty ]; then
  _progress_renderer "$BVD_STATUS_DIR" "${_choices_arr[@]}" &
  RENDERER_PID=$!
fi

for choice in $validated_choices; do
  log=$(mktemp "/tmp/bvd_${choice}_XXXXXX")
  drive_logs["$choice"]="$log"
  process_drive "$choice" >"$log" 2>&1 &
  drive_pids["$choice"]=$!
done

# Fan-in: wait for all drives to finish
total=$(echo "$validated_choices" | wc -w)
overall_ok=true

for choice in $validated_choices; do
  wait "${drive_pids[$choice]}" || overall_ok=false
done

# Stop the renderer and restore the cursor
if [ -n "$RENDERER_PID" ]; then
  touch "$BVD_STATUS_DIR/.done"
  wait "$RENDERER_PID" 2>/dev/null || true
fi
rm -rf "$BVD_STATUS_DIR"

# Print buffered per-drive output
current=0
for choice in $validated_choices; do
  current=$((current + 1))
  printf "\n[%d/%d] /dev/%s\n" "$current" "$total" "$choice"
  cat "${drive_logs[$choice]}"
  rm -f "${drive_logs[$choice]}"
done

printf "\n"
if [ "$overall_ok" = true ]; then
  ui_success "All selected drives have been processed."
else
  ui_warn "Processing complete with errors on one or more drives."
fi
