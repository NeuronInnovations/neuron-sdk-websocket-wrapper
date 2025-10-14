#!/bin/bash

# Fudger Scenario: Block Buyer <- Seller (Incoming) - OFF
# This script removes the firewall rules that block incoming connections to port 1355

set -e

echo "🟢 FUDGER: Allow Buyer <- Seller (Incoming)"
echo "==========================================="
echo "This will remove the block on incoming connections to port 1355"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 Detected macOS - Using pfctl"

    ANCHOR_NAME="neuron-fudger"

    # Flush the rules from the anchor
    echo "🛡️  Flushing firewall rules..."
    sudo pfctl -a "$ANCHOR_NAME" -F rules

    if [ $? -eq 0 ]; then
        echo "✅ Fudger is now INACTIVE"
        echo "   - Incoming connections to port 1355 are ALLOWED"
    else
        echo "❌ Failed to flush firewall rules"
        exit 1
    fi

else
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi
