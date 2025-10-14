#!/bin/zsh

# Fudger Scenario: Block Buyer -> Seller (Outgoing)
# This script starts the tmux test environment and then blocks
# outgoing connections from the buyer to the seller's port (1354)

set -e

# --- Start of tmux setup from test-tmux.sh ---

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up..."
    kill $(lsof -t -i:3001) 2>/dev/null || true
    kill $(lsof -t -i:3002) 2>/dev/null || true
    kill $(lsof -t -i:1354) 2>/dev/null || true
    kill $(lsof -t -i:1355) 2>/dev/null || true
    pkill -f "go run.*seller" 2>/dev/null || true
    pkill -f "go run.*buyer" 2>/dev/null || true
    tmux kill-session -t neuron-test 2>/dev/null || true
}

trap cleanup EXIT

# Check if tmux is installed
if ! command -v tmux &> /dev/null; then
    print_error "tmux is not installed. Install with: brew install tmux"
    exit 1
fi

# Check if wscat is installed
if ! command -v wscat &> /dev/null; then
    print_error "wscat is not installed. Install with: npm install -g wscat"
    exit 1
fi

# Change to project directory
PROJECT_DIR="$(dirname "$0")/../.."
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
cd "$PROJECT_DIR"

print_status "Starting tmux-based buyer-seller test..."
print_info "This will create exactly 6 panes:"
print_info "┌─────────────────┬─────────────────┐"
print_info "│ 🟢 SELLER NODE  │ 🔵 BUYER NODE   │"
print_info "│ (port 3001)     │ (port 3002)     │"
print_info "├─────────────────┼─────────────────┤"
print_info "│ 🟢 SELLER CMDS  │ 🔵 BUYER CMDS   │"
print_info "│ (wscat listener)│ (wscat listener)│"
print_info "├─────────────────┼─────────────────┤"
print_info "│ 🟢 SELLER P2P   │ 🔵 BUYER P2P    │"
print_info "│ (wscat listener)│ (wscat listener)│"
print_info "└─────────────────┴─────────────────┘"

# Cleanup first
cleanup
sleep 2

# Get actual terminal size before creating tmux session
ACTUAL_HEIGHT=$(tput lines)
ACTUAL_WIDTH=$(tput cols)
print_info "Actual terminal size: ${ACTUAL_WIDTH}x${ACTUAL_HEIGHT}"

# Also check environment variables
print_info "LINES: ${LINES:-not set}, COLUMNS: ${COLUMNS:-not set}"

# Check if we're in a real terminal
if [ -t 1 ]; then
    print_info "Running in a real terminal"
else
    print_info "NOT running in a real terminal (might be script/pipe)"
fi

# Create tmux session with explicit size
print_status "Creating tmux session..."
tmux new-session -d -s neuron-test -x "$ACTUAL_WIDTH" -y "$ACTUAL_HEIGHT"

# Create exactly 6 panes or fail
print_status "Setting up 6-pane layout..."

# Check tmux session size
TMUX_SIZE=$(tmux display-message -p -t neuron-test "#{window_width}x#{window_height}")
print_info "Tmux session size: $TMUX_SIZE"

# Create 2x3 grid layout step by step
print_status "Creating 2x3 grid layout..."

# Step 1: Create horizontal split (left/right columns)
if ! tmux split-window -h -t neuron-test; then
    print_error "Failed to create horizontal split"
    exit 1
fi

# Step 2: Split left column vertically (top/middle)
if ! tmux split-window -v -t neuron-test:0.0; then
    print_error "Failed to create first vertical split (left column)"
    exit 1
fi

# Step 3: Split left column again (middle/bottom)
if ! tmux split-window -v -t neuron-test:0.1; then
    print_error "Failed to create second vertical split (left column)"
    exit 1
fi

# Step 4: Split right column vertically (top/middle)
if ! tmux split-window -v -t neuron-test:0.2; then
    print_error "Failed to create first vertical split (right column)"
    exit 1
fi

# Step 5: Split right column again (middle/bottom)
if ! tmux split-window -v -t neuron-test:0.3; then
    print_error "Failed to create second vertical split (right column)"
    exit 1
fi

print_success "Created 6-pane 2x3 grid successfully!"
PANE_COUNT=6

# Set a layout that works well for 6 panes
print_status "Setting layout to 2x3 grid..."
tmux select-layout -t neuron-test tiled

# --- End of tmux setup from test-tmux.sh ---

# --- Start of fudger activation ---

echo "🔴 FUDGER: Block Buyer -> Seller (Outgoing)"
echo "==========================================="
echo "This will block outgoing connections to port 1354 on the loopback interface"
echo ""

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "📱 Detected macOS - Using pfctl"

    ANCHOR_NAME="neuron-fudger"
    RULE_FILE="/tmp/fudger-block-buyer-to-seller.pf"

    # Create the rule file
    cat > "$RULE_FILE" << 'EOF'
# Block outgoing traffic to port 1354 on loopback
block drop out quick on lo0 proto {tcp, udp} from any to any port 1354
EOF

    # Load the rule into the anchor
    echo "🛡️  Loading firewall rules..."
    sudo pfctl -a "$ANCHOR_NAME" -f "$RULE_FILE"

    if [ $? -eq 0 ]; then
        echo "✅ Fudger is now ACTIVE"
        echo "   - Outgoing connections to port 1354 on loopback are BLOCKED"
        echo ""
        echo "💡 To turn off: ./block-buyer-to-seller-off.sh"
    else
        echo "❌ Failed to load firewall rules"
        echo "   - This may be because the anchor '$ANCHOR_NAME' is not configured in /etc/pf.conf"
        exit 1
    fi

else
    echo "❌ Unsupported operating system: $OSTYPE"
    exit 1
fi

# --- End of fudger activation ---

# --- Start of tmux service startup from test-tmux.sh ---

# Set pane titles and start services
print_status "Starting services in panes..."

# Top-left: Seller Node
tmux send-keys -t neuron-test:0.0 "echo '🟢 SELLER NODE - Starting...'" Enter
tmux send-keys -t neuron-test:0.0 "echo 'WebSocket: ws://localhost:3001'" Enter
tmux send-keys -t neuron-test:0.0 "echo 'P2P Port: 1354'" Enter
tmux send-keys -t neuron-test:0.0 "echo '=============================='" Enter
tmux send-keys -t neuron-test:0.0 "go run . --port=1354 --mode=peer --buyer-or-seller=seller --envFile=.seller-env --use-local-address --ws-port=3001" Enter

# Wait for seller to start
print_status "Waiting 10 seconds for seller to initialize..."
sleep 10

# Top-right: Buyer Node
tmux send-keys -t neuron-test:0.1 "echo '🔵 BUYER NODE - Starting...'" Enter
tmux send-keys -t neuron-test:0.1 "echo 'WebSocket: ws://localhost:3002'" Enter
tmux send-keys -t neuron-test:0.1 "echo 'P2P Port: 1355'" Enter
tmux send-keys -t neuron-test:0.1 "echo '=============================='" Enter
tmux send-keys -t neuron-test:0.1 "go run . --port=1355 --mode=peer --buyer-or-seller=buyer --list-of-sellers-source=env --envFile=.buyer-env --use-local-address --ws-port=3002" Enter

sleep 2

# Bottom-left: Seller Commands (wscat listen mode)
tmux send-keys -t neuron-test:0.2 "echo '🟢 SELLER COMMANDS LISTENER'" Enter
tmux send-keys -t neuron-test:0.2 "echo '============================'" Enter
tmux send-keys -t neuron-test:0.2 "echo 'WebSocket: ws://localhost:3001'" Enter
tmux send-keys -t neuron-test:0.2 "echo 'Listening to: /seller/commands'" Enter
tmux send-keys -t neuron-test:0.2 "echo '============================'" Enter
tmux send-keys -t neuron-test:0.2 "echo ''" Enter
tmux send-keys -t neuron-test:0.2 "echo 'Starting wscat in listen mode...'" Enter
tmux send-keys -t neuron-test:0.2 "echo 'Press Ctrl+C to stop listening'" Enter
tmux send-keys -t neuron-test:0.2 "echo ''" Enter
tmux send-keys -t neuron-test:0.2 "wscat -c ws://localhost:3001/seller/commands" Enter

# Bottom-right: Buyer Commands (wscat listen mode)
tmux send-keys -t neuron-test:0.3 "echo '🔵 BUYER COMMANDS LISTENER'" Enter
tmux send-keys -t neuron-test:0.3 "echo '============================'" Enter
tmux send-keys -t neuron-test:0.3 "echo 'WebSocket: ws://localhost:3002'" Enter
tmux send-keys -t neuron-test:0.3 "echo 'Listening to: /buyer/commands'" Enter
tmux send-keys -t neuron-test:0.3 "echo '============================'" Enter
tmux send-keys -t neuron-test:0.3 "echo ''" Enter
tmux send-keys -t neuron-test:0.3 "echo 'Starting wscat in listen mode...'" Enter
tmux send-keys -t neuron-test:0.3 "echo 'Press Ctrl+C to stop listening'" Enter
tmux send-keys -t neuron-test:0.3 "echo ''" Enter
tmux send-keys -t neuron-test:0.3 "wscat -c ws://localhost:3002/buyer/commands" Enter

sleep 2

# Set up P2P listener panes (6-pane mode only)
print_status "Setting up P2P listener panes..."

# Bottom-left: Seller P2P (wscat listen mode)
tmux send-keys -t neuron-test:0.4 "echo '🟢 SELLER P2P LISTENER'" Enter
tmux send-keys -t neuron-test:0.4 "echo '============================'" Enter
tmux send-keys -t neuron-test:0.4 "echo 'WebSocket: ws://localhost:3001'" Enter
tmux send-keys -t neuron-test:0.4 "echo 'Listening to: /seller/p2p'" Enter
tmux send-keys -t neuron-test:0.4 "echo '============================'" Enter
tmux send-keys -t neuron-test:0.4 "echo ''" Enter
tmux send-keys -t neuron-test:0.4 "echo 'Starting wscat in listen mode...'" Enter
tmux send-keys -t neuron-test:0.4 "echo 'Press Ctrl+C to stop listening'" Enter
tmux send-keys -t neuron-test:0.4 "echo ''" Enter
tmux send-keys -t neuron-test:0.4 "wscat -c ws://localhost:3001/seller/p2p" Enter

# Bottom-right: Buyer P2P (wscat listen mode)
tmux send-keys -t neuron-test:0.5 "echo '🔵 BUYER P2P LISTENER'" Enter
tmux send-keys -t neuron-test:0.5 "echo '============================'" Enter
tmux send-keys -t neuron-test:0.5 "echo 'WebSocket: ws://localhost:3002'" Enter
tmux send-keys -t neuron-test:0.5 "echo 'Listening to: /buyer/p2p'" Enter
tmux send-keys -t neuron-test:0.5 "echo '============================'" Enter
tmux send-keys -t neuron-test:0.5 "echo ''" Enter
tmux send-keys -t neuron-test:0.5 "echo 'Starting wscat in listen mode...'" Enter
tmux send-keys -t neuron-test:0.5 "echo 'Press Ctrl+C to stop listening'" Enter
tmux send-keys -t neuron-test:0.5 "echo ''" Enter
tmux send-keys -t neuron-test:0.5 "wscat -c ws://localhost:3002/buyer/p2p" Enter

# Attach to the session
print_success "All services started in tmux session!"
print_info ""
print_info "🎯 TMUX LAYOUT (6 panes):"
print_info "┌─────────────────┬─────────────────┐"
print_info "│ 🟢 SELLER NODE  │ 🔵 BUYER NODE   │"
print_info "│ (port 3001)     │ (port 3002)     │"
print_info "├─────────────────┼─────────────────┤"
print_info "│ 🟢 SELLER CMDS  │ 🔵 BUYER CMDS   │"
print_info "│ (wscat listener)│ (wscat listener)│"
print_info "├─────────────────┼─────────────────┤"
print_info "│ 🟢 SELLER P2P   │ 🔵 BUYER P2P    │"
print_info "│ (wscat listener)│ (wscat listener)│"
print_info "└─────────────────┴─────────────────┘"
print_info ""
print_info "💡 TMUX CONTROLS:"
print_info "  Ctrl+b then arrow keys - Navigate between panes"
print_info "  Ctrl+b then x - Kill current pane"
print_info "  Ctrl+b then d - Detach from session"
print_info "  Ctrl+b then : - Enter command mode"
print_info ""
print_info "⏱️  Wait for P2P connection to establish (about 10-15 seconds)"
print_info "🎮 All bottom panes are listening for WebSocket messages"
print_info "📤 Send commands from other terminals to see responses here"
print_info "🔍 Commands panes listen to /commands endpoints"
print_info "📡 P2P panes listen to /p2p endpoints"
print_info ""
print_status "Attaching to tmux session..."

# Attach to the session
tmux attach-session -t neuron-test

# --- End of tmux service startup from test-tmux.sh ---
