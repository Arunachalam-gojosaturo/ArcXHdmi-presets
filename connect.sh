#!/usr/bin/env bash
# ==============================================================================
# connect.sh - Quick TV & Projector Connect Script for Arch Linux (Hyprland)
# Location: /home/arunachalam/tv/connect.sh
# ==============================================================================

set -euo pipefail
SCRIPT_SOURCE="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"

show_menu() {
    clear
    echo "=============================================================="
    echo "           📺 HYPRLAND TV & PROJECTOR CONNECT TOOL"
    echo "=============================================================="
    echo "  1) 📺 TV ONLY: Use TV as Main Display (Laptop Display OFF)"
    echo "  2) 📽️  PROJECTOR HDMI: Projector as Main Display (1080p@60, Laptop OFF)"
    echo "  3) 💻 LAPTOP ONLY: Restore Laptop Display (External OFF)"
    echo "  4) 🔌 HDMI: Mirror Laptop Screen"
    echo "  5) 🔌 HDMI: Extend Desktop (Dual Monitor)"
    echo "  6) 📶 Wireless: Web Browser Stream (Zero setup)"
    echo "  7) 📶 Wireless: Miracast / Wi-Fi Direct"
    echo "  8) 🔄 Disconnect / Turn Off External Display"
    echo "  9) 🔍 Check Status of HDMI / Displays / Network"
    echo " 10) ❌ Exit"
    echo "=============================================================="
    echo -n "  Select an option [1-10]: "
}

run_tv_only() {
    echo ""
    "$SCRIPT_DIR/tv-only.sh"
}

run_projector_only() {
    echo ""
    "$SCRIPT_DIR/projector-hdmi.sh" only
}

run_laptop_only() {
    echo ""
    "$SCRIPT_DIR/laptop-only.sh"
}

run_hdmi_mirror() {
    echo ""
    "$SCRIPT_DIR/tv-hdmi.sh" mirror
}

run_hdmi_extend() {
    echo ""
    "$SCRIPT_DIR/tv-hdmi.sh" extend
}

run_wifi_stream() {
    echo ""
    exec python3 "$SCRIPT_DIR/tv-stream.py"
}

run_miracast() {
    echo ""
    "$SCRIPT_DIR/tv-miracast.sh"
}

run_disconnect() {
    echo ""
    "$SCRIPT_DIR/tv-hdmi.sh" off
}

run_status() {
    echo ""
    "$SCRIPT_DIR/projector-hdmi.sh" status
    echo ""
    echo "--- Network Status ---"
    nmcli -c no dev status | grep -E "wifi|p2p" || true
    echo ""
    if [ "${1:-}" = "interactive" ]; then
        read -rp "Press Enter to return to menu..."
    fi
}

CMD="${1:-}"

case "$CMD" in
    1|tv|tv-only)
        run_tv_only
        ;;
    2|projector|projector-only|proj)
        run_projector_only
        ;;
    3|laptop|laptop-only)
        run_laptop_only
        ;;
    4|hdmi|mirror)
        run_hdmi_mirror
        ;;
    5|extend)
        run_hdmi_extend
        ;;
    6|wifi|stream)
        run_wifi_stream
        ;;
    7|miracast)
        run_miracast
        ;;
    8|off|disconnect)
        run_disconnect
        ;;
    9|status)
        run_status
        ;;
    "")
        while true; do
            show_menu
            read -r choice
            case "$choice" in
                1) run_tv_only; break ;;
                2) run_projector_only; break ;;
                3) run_laptop_only; break ;;
                4) run_hdmi_mirror; break ;;
                5) run_hdmi_extend; break ;;
                6) run_wifi_stream; break ;;
                7) run_miracast; break ;;
                8) run_disconnect; break ;;
                9) run_status interactive ;;
                10|q|exit) echo "Exiting."; exit 0 ;;
                *) echo "Invalid option. Please choose 1-10." ; sleep 1 ;;
            esac
        done
        ;;
    *)
        echo "Usage: $0 [tv-only|projector|laptop-only|mirror|extend|wifi|miracast|off|status]"
        exit 1
        ;;
esac
