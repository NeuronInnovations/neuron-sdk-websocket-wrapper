#!/bin/bash

# Fudger Scenarios - Status
# This script shows the active fudger rules

set -e

echo "🔍 FUDGER SCENARIOS STATUS"
echo "========================="
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 Detected macOS - Using pfctl"

    ANCHOR_NAME="neuron-fudger"

    # Check the rules in the anchor
    echo "🛡️  Checking for active rules in anchor '$ANCHOR_NAME'..."
    RULES=$(sudo pfctl -a "$ANCHOR_NAME" -s rules 2>/dev/null)

    if [ -z "$RULES" ]; then
        echo "🟢 No active fudger rules found."
    else
        echo "🔴 Active fudger rules:"
        echo "$RULES"
    fi

else
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi
