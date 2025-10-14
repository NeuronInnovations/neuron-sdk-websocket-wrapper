#!/bin/bash

# Network Fudger OFF - Restores normal seller to buyer connectivity
# This script removes the firewall rules blocking seller connections

set -e

echo "🟢 NETWORK FUDGER: TURNING OFF"
echo "================================"
echo "This will restore normal seller to buyer connectivity"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 Detected macOS - Using pfctl"
    
    # Check if pfctl is available
    if ! command -v pfctl &> /dev/null; then
        echo "❌ Error: pfctl not found. Please install it or run as root."
        exit 1
    fi
    
    # Disable pfctl (this removes all custom rules)
    echo "🛡️  Disabling firewall rules..."
    sudo pfctl -d
    
    if [ $? -eq 0 ]; then
        echo "✅ Network fudger is now INACTIVE"
        echo "   - Seller can now connect to buyer normally"
        echo "   - Normal P2P communication restored"
        echo ""
        echo "💡 To turn on: ./network-fudger-on.sh"
    else
        echo "❌ Failed to disable firewall rules"
        exit 1
    fi
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🐧 Detected Linux - Using iptables"
    
    # Check if iptables is available
    if ! command -v iptables &> /dev/null; then
        echo "❌ Error: iptables not found. Please install it or run as root."
        exit 1
    fi
    
    # Remove the blocking rules
    echo "🛡️  Removing iptables rules..."
    sudo iptables -D OUTPUT -p udp --dport 1355 -j DROP 2>/dev/null || true
    sudo iptables -D OUTPUT -p tcp --dport 1355 -j DROP 2>/dev/null || true
    
    if [ $? -eq 0 ]; then
        echo "✅ Network fudger is now INACTIVE"
        echo "   - Seller can now connect to buyer normally"
        echo "   - Normal P2P communication restored"
        echo ""
        echo "💡 To turn on: ./network-fudger-on.sh"
    else
        echo "❌ Failed to remove iptables rules"
        exit 1
    fi
    
else
    echo "❌ Unsupported operating system: $OSTYPE"
    echo "   Please manually remove port 1355 blocks on your system"
    exit 1
fi

echo ""
echo "🧪 TESTING INSTRUCTIONS:"
echo "1. Start the buyer: go run . --port=1355 --mode=peer --buyer-or-seller=buyer --list-of-sellers-source=env --envFile=.buyer-env --use-local-address --ws-port=3002"
echo "2. Start the seller: go run . --port=3001 --mode=peer --buyer-or-seller=seller --envFile=.seller-env --use-local-address --ws-port=3001"
echo "3. Normal P2P communication should work"
echo "4. Turn on fudger: ./network-fudger-on.sh"
