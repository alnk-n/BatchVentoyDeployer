#!/bin/bash
# Batch Ventoy Deployer installer
# Run once as root to install dependencies and set up the environment.
# Usage: sudo ./install.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
 
source "$SCRIPT_DIR/config/defaults.conf"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/ventoy.sh"
