#!/bin/bash

# Network Fudger ON - Blocks seller from connecting to buyer
# This script blocks outgoing connections from seller to buyer's port (1355)

set -e

echo "🔴 NETWORK FUDGER: TURNING ON"
echo "================================"
echo "This will block the seller from connecting to the buyer"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 Detected macOS - Using pfctl"
    
    # Check if pfctl is available
    if ! command -v pfctl &> /dev/null; then
        echo "❌ Error: pfctl not found. Please install it or run as root."
        exit 1
    fi
    
    # Create a temporary pfctl rule file
    cat > /tmp/neuron-fudger.pf << 'EOF'
# Neuron Network Fudger - Block seller to buyer connections
block out proto udp from any to any port 1355
block out proto tcp from any to any port 1355
EOF
    
    # Load the rule
    echo "🛡️  Loading firewall rules..."
    sudo pfctl -f /tmp/neuron-fudger.pf
    
    if [ $? -eq 0 ]; then
        echo "✅ Network fudger is now ACTIVE"
        echo "   - Seller cannot connect to buyer on port 1355"
        echo "   - This will trigger comprehensive error reporting"
        echo ""
        echo "🔍 Checking rules immediately after loading:"
        sudo pfctl -s rules
        echo ""
        echo "💡 To turn off: ./network-fudger-off.sh"
    else
        echo "❌ Failed to load firewall rules"
        exit 1
    fi
    
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "🐧 Detected Linux - Using iptables"
    
    # Check if iptables is available
    if ! command -v iptables &> /dev/null; then
        echo "❌ Error: iptables not found. Please install it or run as root."
        exit 1
    fi
    
    # Block outgoing connections to buyer's port
    echo "🛡️  Adding iptables rules..."
    sudo iptables -A OUTPUT -p udp --dport 1355 -j DROP
    sudo iptables -A OUTPUT -p tcp --dport 1355 -j DROP
    
    if [ $? -eq 0 ]; then
        echo "✅ Network fudger is now ACTIVE"
        echo "   - Seller cannot connect to buyer on port 1355"
        echo "   - This will trigger comprehensive error reporting"
        echo ""
        echo "💡 To turn off: ./network-fudger-off.sh"
    else
        echo "❌ Failed to add iptables rules"
        exit 1
    fi
    
else
    echo "❌ Unsupported operating system: $OSTYPE"
    echo "   Please manually block port 1355 on your system"
    exit 1
fi

echo ""
echo "🧪 TESTING INSTRUCTIONS:"
echo "1. Start the buyer: go run . --port=1355 --mode=peer --buyer-or-seller=buyer --list-of-sellers-source=env --envFile=.buyer-env --use-local-address --ws-port=3002"
echo "2. Start the seller: go run . --port=3001 --mode=peer --buyer-or-seller=seller --envFile=.seller-env --use-local-address --ws-port=3001"
echo "3. Watch for comprehensive error reports in your Hedera self-error topic"
echo "4. Turn off fudger: ./network-fudger-off.sh"