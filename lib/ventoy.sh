#!/bin/bash

# lib/ventoy.sh
# Ventoy download, checksum verification, and disk installation.
# Sourced by ventoy-creator.sh: do not run directly.

# Downloads the Ventoy tarball and verifies its SHA-256 checksum
ventoy_download() {
  ui_msg "Downloading Ventoy ${VENTOY_VERSION}..."

  if ! curl -L -O "$VENTOY_URL"; then
    ui_error "Failed to download Ventoy tarball."
    exit 1
  fi

  ui_msg "Verifying checksum..."
  local sha_url="https://github.com/ventoy/Ventoy/releases/download/v${VENTOY_VERSION}/sha256.txt"
  local sha_file="sha256.txt"

  if curl -L -o "$sha_file" "$sha_url" 2>/dev/null; then
    if grep "$VENTOY_ARCHIVE" "$sha_file" | tr -d '\r' | sha256sum -c -; then
      ui_success "Checksum verified."
      rm -f "$sha_file"
    else
      ui_error "Checksum mismatch. Download may be corrupted. Exiting."
      rm -f "$VENTOY_ARCHIVE" "$sha_file"
      exit 1
    fi
  else
    ui_warn "Could not fetch checksum file. Skipping verification."
  fi
}

# Extracts the Ventoy tarball and removes the archive.
ventoy_extract() {
  ui_msg "Extracting Ventoy..."
  if tar -xzf "$VENTOY_ARCHIVE"; then
    rm -f "$VENTOY_ARCHIVE"
    ui_success "Ventoy ${VENTOY_VERSION} ready."
  else
    ui_error "Failed to extract Ventoy tarball."
    exit 1
  fi
}

# Installs Ventoy onto a block device.
ventoy_install_to() {
  local device="$1"
  local ventoy_dir
  ventoy_dir="$(dirname "$VENTOY_SCRIPT")"
  (cd "$ventoy_dir" && printf 'y\ny\n' | ./Ventoy2Disk.sh -I -s -g "$device")
}