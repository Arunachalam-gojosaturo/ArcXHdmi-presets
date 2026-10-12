#!/usr/bin/env bash
# ==============================================================================
# tv-miracast.sh - Miracast / Wi-Fi Direct Manager (SAFE FOR NETWORKMANAGER)
# Does NOT disable or stop NetworkManager service.
# ==============================================================================

set -euo pipefail

echo "============================================================"
echo "  📶 MiracleCast Wi-Fi Direct (NetworkManager Preserved)"
echo "============================================================"

# Ensure miraclecast tools are present
if ! command -v miracle-wifictl &>/dev/null; then
    echo "❌ miracle-wifictl not found. Please ensure miraclecast is installed."
    exit 1
fi

echo "✅ NetworkManager is running and will NOT be disabled."
echo "   Checking Wi-Fi and P2P devices..."
nmcli dev status | grep -E "wifi|p2p" || true
echo ""
echo "📺 TV Instructions:"
echo "1. On your TV, open 'Screen Mirroring', 'Miracast', or 'Wireless Display'."
echo "2. Keep this terminal open while MiracleCast scans for your TV."
echo "============================================================"
echo ""

# Launch miracle-wifictl interactively
echo "Starting miracle-wifictl..."
echo "Tips inside miracle-wifictl:"
echo "  - Type 'p2p-scan' to scan for your TV"
echo "  - Type 'list-peers' to see found TVs"
echo "  - Type 'connect <id>' to pair"
echo "  - Type 'quit' to exit"
echo ""

exec miracle-wifictl
