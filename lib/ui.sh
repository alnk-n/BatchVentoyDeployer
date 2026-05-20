#!/bin/bash
# All UI output and input prompts.
# Sourced by ventoy-creator.sh, do not run directly.

# GUI mode: true if a display server is reachable AND zenity is installed and functional.
# Deliberately false over plain SSH (no DISPLAY/WAYLAND_DISPLAY) or in headless/cron contexts.
if { [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; } \
   && command -v zenity &>/dev/null \
   && zenity --version &>/dev/null 2>&1; then
  GUI_MODE=true
else
  GUI_MODE=false
fi

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
  if [ "$GUI_MODE" = true ]; then
    local col_args=()
    while IFS= read -r line; do
      local name model size
      name=$(grep -oP '(?<=NAME=")[^"]*' <<<"$line")
      model=$(grep -oP '(?<=MODEL=")[^"]*' <<<"$line")
      size=$(grep -oP '(?<=SIZE=")[^"]*' <<<"$line")
      [[ "$name" == loop* ]] && continue
      [ -z "$name" ] && continue
      col_args+=("FALSE" "$name" "${model:-}" "$size")
    done < <(lsblk --nodeps -Po NAME,MODEL,SIZE)

    local chosen
    chosen=$(zenity --list --checklist \
      --title="BatchVentoyDeployer" \
      --text="Select drives to format with Ventoy:" \
      --column="Select" --column="Device" --column="Model" --column="Size" \
      --separator=" " \
      "${col_args[@]}" 2>/dev/null) || true
    DISK_CHOICES="$chosen"
  else
    printf "(press Enter to exit)\n"
    printf "Enter the disks you wish to format, separated by spaces (e.g. sdd sde sdf):\n"
    read -r -p "> " DISK_CHOICES
  fi
  export DISK_CHOICES
}

ui_confirm_selection() {
  local devices=("$@")
  local text="The following disks will be ERASED and formatted with Ventoy:\n\n"

  for device in "${devices[@]}"; do
    local model size
    model=$(lsblk --nodeps -no MODEL "$device" 2>/dev/null | xargs)
    size=$(lsblk --nodeps -no SIZE "$device" 2>/dev/null | xargs)
    text+="  $device  ·  $model  $size\n"
  done
  text+="\nThis will destroy all data on the above disks.\nThe process will then run unattended until complete."

  if [ "$GUI_MODE" = true ]; then
    zenity --question \
      --title="BatchVentoyDeployer — Confirm" \
      --text="$text" \
      --ok-label="Format" \
      --cancel-label="Abort" \
      --width=450 2>/dev/null
    return $?
  else
    printf "\n%b\n\n" "$text"
    read -r -p "Confirm and proceed? [y/N] > " confirm
    case "$confirm" in
      [yY]) return 0 ;;
      *)    return 1 ;;
    esac
  fi
}

ui_msg()     { printf "%s\n" "$1"; }
ui_success() { printf "✔ %s\n" "$1"; }
ui_warn()    { printf "⚠ %s\n" "$1"; }
ui_error()   { printf "✘ %s\n" "$1" >&2; }
