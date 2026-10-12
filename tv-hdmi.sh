#!/usr/bin/env bash
# ==============================================================================
# tv-hdmi.sh - TV HDMI Mirror & Extend Manager for Hyprland
# Works natively with Hyprland 0.56+ Lua configuration
# ==============================================================================

set -euo pipefail

MAIN_DISPLAY="eDP-1"

# Function to detect connected external port
detect_external_port() {
    # Check DRM connector status
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

# Function to list all ports
list_ports() {
    echo "--- Connector Port Status ---"
    for p in /sys/class/drm/card*-*/status; do
        if [ -f "$p" ]; then
            local port status
            port=$(basename "$(dirname "$p")" | sed -E 's/card[0-9]+-//')
            status=$(cat "$p")
            echo "  Port: $port  --> Status: $status"
        fi
    done
}

ACTION="${1:-mirror}"
PORT="${2:-}"

if [ -z "$PORT" ]; then
    DETECTED_PORT=$(detect_external_port || true)
    if [ -n "$DETECTED_PORT" ]; then
        PORT="$DETECTED_PORT"
        echo "🔍 Detected active external display on: $PORT"
    else
        PORT="HDMI-A-1" # Default fallback
    fi
fi

case "$ACTION" in
    tv-only|tv)
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        exec "$SCRIPT_DIR/tv-only.sh" "${2:-1}" "${3:-1920x1080@60}"
        ;;
    laptop-only|laptop)
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        exec "$SCRIPT_DIR/laptop-only.sh"
        ;;
    mirror)
        echo "📺 Mirroring laptop screen ($MAIN_DISPLAY) onto TV ($PORT)..."
        hyprctl eval "hl.monitor({output = \"$PORT\", mode = \"1920x1080@60\", position = \"auto\", scale = 1, mirror = \"$MAIN_DISPLAY\"})" >/dev/null
        echo "✅ Screen mirrored successfully to $PORT!"
        ;;
    extend)
        echo "📺 Extending desktop to TV ($PORT) next to $MAIN_DISPLAY..."
        hyprctl eval "hl.monitor({output = \"$PORT\", mode = \"1920x1080@60\", position = \"auto-right\", scale = 1})" >/dev/null
        echo "✅ TV display extended successfully to $PORT!"
        ;;
    off|disconnect)
        echo "🔌 Disabling TV display ($PORT)..."
        hyprctl eval "hl.monitor({output = \"$PORT\", disabled = true})" >/dev/null || hyprctl reload >/dev/null
        echo "✅ TV display disconnected/disabled."
        ;;
    status)
        list_ports
        echo ""
        echo "--- Active Hyprland Monitors ---"
        hyprctl monitors
        ;;
    *)
        echo "Usage: $0 [tv-only|laptop-only|mirror|extend|off|status] [SCALE] [MODE]"
        echo "Examples:"
        echo "  $0 tv-only       # TV as main display, laptop display OFF"
        echo "  $0 laptop-only   # Restore laptop display, TV OFF"
        echo "  $0 mirror        # Mirrors laptop screen to TV at 60Hz"
        echo "  $0 extend        # Extends desktop to TV at 60Hz"
        echo "  $0 off           # Disables TV display"
        echo "  $0 status        # Shows current monitor & cable status"
        exit 1
        ;;
esac
