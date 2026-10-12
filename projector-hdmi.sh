#!/usr/bin/env bash
# ==============================================================================
# projector-hdmi.sh - Projector HDMI Display Manager for Arch Linux (Hyprland)
# Matches tv-only.sh pixel-perfect resolution (1920x1080@60, 1x scale)
# Location: /home/arunachalam/tv/projector-hdmi.sh
# ==============================================================================

set -euo pipefail

LAPTOP_DISPLAY="eDP-1"
LAPTOP_MODE="2160x1440@60"
LAPTOP_SCALE="1"

# Default projector display settings (matches tv-only.sh for razor-sharp quality)
DEFAULT_MODE="1920x1080@60"
DEFAULT_SCALE="1"
PROJECTOR_PORT=""

# Auto-detect connected external display (HDMI-A-1, HDMI-A-2, DP-1, etc.)
detect_projector_port() {
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

ensure_projector_port() {
    if [ -n "$PROJECTOR_PORT" ]; then
        return 0
    fi
    PROJECTOR_PORT=$(detect_projector_port || true)
    if [ -n "$PROJECTOR_PORT" ]; then
        echo "🔍 Detected connected projector on: $PROJECTOR_PORT"
    else
        echo "⚠️  No connected external display detected! Falling back to HDMI-A-1..."
        PROJECTOR_PORT="HDMI-A-1"
    fi
}

# Print available modes if detected in sysfs
check_supported_modes() {
    local modes_file
    modes_file=$(ls /sys/class/drm/card*-"$PROJECTOR_PORT"/modes 2>/dev/null | head -n 1 || true)
    if [ -f "$modes_file" ]; then
        echo "📋 Supported hardware modes reported by projector:"
        head -n 5 "$modes_file" | sed 's/^/   - /' || true
    fi
}

# Function to list all ports
list_status() {
    echo "=============================================================="
    echo "             📽️  PROJECTOR & PORT STATUS"
    echo "=============================================================="
    for p in /sys/class/drm/card*-*/status; do
        if [ -f "$p" ]; then
            local port status
            port=$(basename "$(dirname "$p")" | sed -E 's/card[0-9]+-//')
            status=$(cat "$p")
            echo "  Port: $port  --> Status: $status"
        fi
    done
    echo ""
    echo "--- Active Hyprland Monitors ---"
    hyprctl monitors
}

# 1. Projector-Only Mode (Exact same quality and behavior as tv-only.sh)
mode_projector_only() {
    local scale="${1:-$DEFAULT_SCALE}"
    local mode="${2:-$DEFAULT_MODE}"

    ensure_projector_port

    echo "=============================================================="
    echo "  📽️  Switching to Projector-Only Mode"
    echo "  Projector Output: $PROJECTOR_PORT"
    echo "  Resolution/Mode:  $mode (Crisp 1080p @ 60Hz)"
    echo "  Scale:            $scale (1x Pixel-Perfect)"
    echo "  Laptop Screen:    $LAPTOP_DISPLAY (will be TURNED OFF)"
    echo "=============================================================="

    check_supported_modes

    # 1. Enable projector at (0,0) as primary display with native 1080p
    hyprctl eval "hl.monitor({output = \"$PROJECTOR_PORT\", disabled = false, mode = \"$mode\", position = \"0x0\", scale = $scale})" >/dev/null
    hyprctl eval "hl.dispatch(hl.dsp.dpms('on', '$PROJECTOR_PORT'))" >/dev/null 2>&1 || true

    # 2. Disable laptop internal display
    hyprctl eval "hl.monitor({output = \"$LAPTOP_DISPLAY\", disabled = true})" >/dev/null

    # 3. Ensure backlight/power is completely off on laptop display
    hyprctl eval "hl.dispatch(hl.dsp.dpms('off', '$LAPTOP_DISPLAY'))" >/dev/null 2>&1 || true

    echo ""
    echo "✅ Projector ($PROJECTOR_PORT) is now your primary display!"
    echo "💡 Laptop display ($LAPTOP_DISPLAY) is powered off."
    echo "💡 To restore your laptop screen at any time, run:"
    echo "   ~/tv/projector-hdmi.sh restore   OR   ~/tv/laptop-only.sh"
}

# 2. Mirror Mode
mode_mirror() {
    local mode="${1:-$DEFAULT_MODE}"
    ensure_projector_port
    echo "📽️  Mirroring laptop screen onto projector ($PROJECTOR_PORT at $mode)..."
    hyprctl eval "hl.monitor({output = \"$PROJECTOR_PORT\", disabled = false, mode = \"$mode\", position = \"auto\", scale = 1, mirror = \"$LAPTOP_DISPLAY\"})" >/dev/null
    hyprctl eval "hl.dispatch(hl.dsp.dpms('on', '$PROJECTOR_PORT'))" >/dev/null 2>&1 || true
    echo "✅ Screen mirrored successfully to projector ($PROJECTOR_PORT)!"
}

# 3. Extend Mode
mode_extend() {
    local mode="${1:-$DEFAULT_MODE}"
    ensure_projector_port
    echo "📽️  Extending desktop to projector ($PROJECTOR_PORT at $mode)..."
    hyprctl eval "hl.monitor({output = \"$PROJECTOR_PORT\", disabled = false, mode = \"$mode\", position = \"auto-right\", scale = 1})" >/dev/null
    hyprctl eval "hl.dispatch(hl.dsp.dpms('on', '$PROJECTOR_PORT'))" >/dev/null 2>&1 || true
    echo "✅ Extended display active on projector ($PROJECTOR_PORT)!"
}

# 4. Restore Laptop Mode
mode_restore() {
    ensure_projector_port
    echo "=============================================================="
    echo "  💻 Restoring Laptop Screen & Turning Off Projector"
    echo "  Laptop Screen:    $LAPTOP_DISPLAY ($LAPTOP_MODE)"
    echo "  Projector Output: $PROJECTOR_PORT (disabled)"
    echo "=============================================================="

    # Turn laptop internal display back on
    hyprctl eval "hl.monitor({output = \"$LAPTOP_DISPLAY\", disabled = false, mode = \"$LAPTOP_MODE\", position = \"0x0\", scale = $LAPTOP_SCALE})" >/dev/null
    hyprctl eval "hl.dispatch(hl.dsp.dpms('on', '$LAPTOP_DISPLAY'))" >/dev/null 2>&1 || true

    # Turn projector off
    hyprctl eval "hl.monitor({output = \"$PROJECTOR_PORT\", disabled = true})" >/dev/null 2>&1 || true

    echo "✅ Laptop display ($LAPTOP_DISPLAY) restored!"
}

# Argument handling
FIRST_ARG="${1:-}"

case "$FIRST_ARG" in
    ""|only|projector-only|projector)
        # Default behavior: run projector-only just like tv-only.sh
        SCALE="${2:-$DEFAULT_SCALE}"
        MODE="${3:-$DEFAULT_MODE}"
        mode_projector_only "$SCALE" "$MODE"
        ;;
    mirror)
        MODE="${2:-$DEFAULT_MODE}"
        mode_mirror "$MODE"
        ;;
    extend)
        MODE="${2:-$DEFAULT_MODE}"
        mode_extend "$MODE"
        ;;
    restore|laptop|laptop-only|off|disconnect)
        mode_restore
        ;;
    status)
        list_status
        ;;
    help|-h|--help)
        echo "=============================================================="
        echo "              📽️  PROJECTOR HDMI SCRIPT"
        echo "=============================================================="
        echo "Usage: $0 [ACTION|SCALE] [MODE]"
        echo ""
        echo "Commands:"
        echo "  $0                  # (Default) Projector-Only (same quality as tv-only.sh)"
        echo "  $0 only             # Same as default: laptop OFF, projector 1080p@60"
        echo "  $0 mirror           # Mirror laptop display onto projector"
        echo "  $0 extend           # Dual-screen: extend desktop to projector"
        echo "  $0 restore          # Restore laptop screen and disable projector"
        echo "  $0 off              # Alias for restore"
        echo "  $0 status           # Check HDMI ports and active monitor status"
        echo ""
        echo "Custom Resolution / Scale:"
        echo "  $0 only 1 1920x1080@60"
        echo "  $0 only 1 1280x720@60"
        echo "=============================================================="
        ;;
    *)
        # If user passed custom scale or mode directly as first argument (e.g. ./projector-hdmi.sh 1 1920x1080@60 or 1920x1080@60)
        if [[ "$FIRST_ARG" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            SCALE="$FIRST_ARG"
            MODE="${2:-$DEFAULT_MODE}"
            mode_projector_only "$SCALE" "$MODE"
        elif [[ "$FIRST_ARG" =~ [0-9]+x[0-9]+ ]]; then
            MODE="$FIRST_ARG"
            SCALE="${2:-$DEFAULT_SCALE}"
            mode_projector_only "$SCALE" "$MODE"
        else
            echo "⚠️  Unknown action: '$FIRST_ARG'"
            echo "Run '$0 help' for available options."
            exit 1
        fi
        ;;
esac
