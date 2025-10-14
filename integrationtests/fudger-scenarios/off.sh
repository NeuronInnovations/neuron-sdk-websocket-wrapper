#!/bin/bash

# Fudger Scenarios - All OFF
# This script removes all fudger firewall rules

set -e

echo "⚪ FUDGER SCENARIOS: ALL OFF"
echo "============================"
echo "This will remove all fudger firewall rules"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 Detected macOS - Using pfctl"

    ANCHOR_NAME="neuron-fudger"

    # Flush the rules from the anchor
    echo "🛡️  Flushing all rules from anchor '$ANCHOR_NAME'..."
    sudo pfctl -a "$ANCHOR_NAME" -F rules

    if [ $? -eq 0 ]; then
        echo "✅ All fudger rules have been removed."
    else
        echo "❌ Failed to flush firewall rules"
        exit 1
    fi

else
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi
