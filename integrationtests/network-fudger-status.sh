#!/bin/bash

# Network Fudger Status - Shows current firewall state
# This script checks if the network fudger is active or inactive

set -e

echo "🔍 NETWORK FUDGER STATUS"
echo "========================="
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 Detected macOS - Checking pfctl status"

    # Check if pfctl is available
    if ! command -v pfctl &> /dev/null; then
        echo "❌ Error: pfctl not found"
        exit 1
    fi

    # Check if our specific rules are loaded using sudo
    echo "🔍 Checking for fudger rules with sudo..."
    if sudo pfctl -s rules 2>/dev/null | grep -q "block.*out.*proto.*udp.*port.*1355"; then
        echo "🔴 Network fudger is ACTIVE"
        echo "   - Seller connections to buyer (port 1355) are BLOCKED"
        echo "   - This will trigger comprehensive error reporting"
    else
        echo "🟢 Network fudger is INACTIVE"
        echo "   - No specific port 1355 blocking rules found"
        echo "   - Normal P2P communication should work"
    fi

elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🐧 Detected Linux - Checking iptables status"

    # Check if iptables is available
    if ! command -v iptables &> /dev/null; then
        echo "❌ Error: iptables not found"
        exit 1
    fi

    # Check if our blocking rules exist
    if sudo iptables -L OUTPUT -n 2>/dev/null | grep -q "DROP.*dpt:1355"; then
        echo "🔴 Network fudger is ACTIVE"
        echo "   - Seller connections to buyer (port 1355) are BLOCKED"
        echo "   - This will trigger comprehensive error reporting"
    else
        echo "🟢 Network fudger is INACTIVE"
        echo "   - No port 1355 blocking rules found"
        echo "   - Normal P2P communication should work"
    fi

else
    echo "❌ Unsupported operating system: $OSTYPE"
    echo "   Please manually check your firewall settings"
    exit 1
fi

echo ""
echo "💡 COMMANDS:"
echo "   Turn ON:  sudo ./network-fudger-on.sh"
echo "   Turn OFF: sudo ./network-fudger-off.sh"
echo "   Status:   ./network-fudger-status.sh"