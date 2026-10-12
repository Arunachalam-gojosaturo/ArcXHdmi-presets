#!/usr/bin/env bash
# ==============================================================================
# projector-only.sh - Use Projector as Main Display and Turn Off Laptop Screen
# Matches tv-only.sh (1920x1080@60, 1x scale, laptop screen off)
# Location: /home/arunachalam/tv/projector-only.sh
# ==============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/projector-hdmi.sh" only "${1:-1}" "${2:-1920x1080@60}"
