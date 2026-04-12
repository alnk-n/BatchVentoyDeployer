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

  local sha_url="${VENTOY_URL}.sha256"
  local sha_file="${VENTOY_ARCHIVE}.sha256"

  ui_msg "Verifying checksum..."
  if curl -L -o "$sha_file" "$sha_url" 2>/dev/null; then
    if sha256sum -c "$sha_file"; then
      ui_success "Checksum verified."
      rm -f "$sha_file"
    else
      ui_error "Checksum mismatch — download may be corrupted. Exiting."
      rm -f "$VENTOY_ARCHIVE" "$sha_file"
      exit 1
    fi
  else
    ui_warn "Could not fetch checksum file — skipping verification."
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
  printf 'y\ny\n' | "$VENTOY_SCRIPT" -I -s -g "$device"
}