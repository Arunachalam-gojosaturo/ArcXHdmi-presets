#!/usr/bin/env bash
# ==============================================================================
# tv-only.sh - Use TV as Main Display and Turn Off Laptop Display
# Designed for Arch Linux running Hyprland (illogical-impulse / End-4 Lua setup)
# Location: /home/arunachalam/tv/tv-only.sh
# ==============================================================================

set -euo pipefail

LAPTOP_DISPLAY="eDP-1"
SCALE="${1:-1}"
MODE="${2:-1920x1080@60}"

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

if [ -z "$TV_PORT" ]; then
    echo "⚠️  No connected external display detected! Falling back to HDMI-A-1..."
    TV_PORT="HDMI-A-1"
fi

echo "=============================================================="
echo "  📺 Switching to TV-Only Mode"
echo "  TV Output:     $TV_PORT"
echo "  Mode:          $MODE"
echo "  Scale:         $SCALE"
echo "  Laptop Screen: $LAPTOP_DISPLAY (will be TURNED OFF)"
echo "=============================================================="

# 1. Enable TV at (0,0) as the primary display
hyprctl eval "hl.monitor({output = \"$TV_PORT\", disabled = false, mode = \"$MODE\", position = \"0x0\", scale = $SCALE})" >/dev/null
hyprctl eval "hl.dispatch(hl.dsp.dpms('on', '$TV_PORT'))" >/dev/null 2>&1 || true

# 2. Disable laptop internal display
hyprctl eval "hl.monitor({output = \"$LAPTOP_DISPLAY\", disabled = true})" >/dev/null

# 3. Ensure backlight/power is off on laptop display
hyprctl eval "hl.dispatch(hl.dsp.dpms('off', '$LAPTOP_DISPLAY'))" >/dev/null 2>&1 || true

echo "✅ Done! Your TV ($TV_PORT) is now the main display."
echo "💡 Laptop display ($LAPTOP_DISPLAY) is turned off."
echo "💡 To restore your laptop screen at any time, run:"
echo "   ~/tv/laptop-only.sh"
