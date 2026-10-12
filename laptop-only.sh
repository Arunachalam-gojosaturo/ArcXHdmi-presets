#!/usr/bin/env bash
# ==============================================================================
# laptop-only.sh - Restore Laptop Display and Turn Off External TV
# Designed for Arch Linux running Hyprland (illogical-impulse / End-4 Lua setup)
# Location: /home/arunachalam/tv/laptop-only.sh
# ==============================================================================

set -euo pipefail

LAPTOP_DISPLAY="eDP-1"
LAPTOP_MODE="2160x1440@60"
LAPTOP_SCALE="1"

# Auto-detect connected external display (e.g. HDMI-A-1)
detect_tv_port() {
    for p in /sys/class/drm/card*-*/status; do
        if [ -f "$p" ] && grep -q "^connected" "$p"; then
            local port
            port=$(basename "$(dirname "$p")" | sed -E 's/card[0-9]+-//')
            if [[ "$port" != eDP* ]]; then
                echo "$port"
                return 0
            fi
        fi
    done
    return 1
}

TV_PORT=$(detect_tv_port || true)
[ -z "$TV_PORT" ] && TV_PORT="HDMI-A-1"

echo "=============================================================="
echo "  💻 Switching back to Laptop-Only Mode"
echo "  Laptop Screen: $LAPTOP_DISPLAY ($LAPTOP_MODE)"
echo "  TV Output:     $TV_PORT (will be disabled)"
echo "=============================================================="

# 1. Enable laptop internal display
hyprctl eval "hl.monitor({output = \"$LAPTOP_DISPLAY\", disabled = false, mode = \"$LAPTOP_MODE\", position = \"0x0\", scale = $LAPTOP_SCALE})" >/dev/null

# 2. Turn backlight back on if it was off
hyprctl eval "hl.dispatch(hl.dsp.dpms('on', '$LAPTOP_DISPLAY'))" >/dev/null 2>&1 || true

# 3. Disable TV display
hyprctl eval "hl.monitor({output = \"$TV_PORT\", disabled = true})" >/dev/null 2>&1 || true

echo "✅ Laptop display ($LAPTOP_DISPLAY) restored!"
