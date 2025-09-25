#!/bin/zsh

# Tmux-based test script for buyer-seller communication
# This script creates a single terminal with 4 split panes

set -e

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
PROJECT_DIR="$(dirname "$0")/.."
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
cd "$PROJECT_DIR"

print_status "Starting tmux-based buyer-seller test..."
print_info "This will create a single terminal with 4 split panes:"
print_info "┌─────────────────┬─────────────────┐"
print_info "│ 🟢 SELLER NODE  │ 🔵 BUYER NODE   │"
print_info "│ (port 3001)     │ (port 3002)     │"
print_info "├─────────────────┼─────────────────┤"
print_info "│ 🟢 SELLER CMDS  │ 🔵 BUYER CMDS   │"
print_info "│ (test commands) │ (test commands) │"
print_info "└─────────────────┴─────────────────┘"

# Cleanup first
cleanup
sleep 2

# Create tmux session
print_status "Creating tmux session..."
tmux new-session -d -s neuron-test

# Split into 4 panes
print_status "Setting up 4-pane layout..."

# Split horizontally (top/bottom)
tmux split-window -h -t neuron-test

# Split the top pane vertically (top-left/top-right)
tmux split-window -v -t neuron-test:0.0

# Split the bottom pane vertically (bottom-left/bottom-right)  
tmux split-window -v -t neuron-test:0.1

# Resize panes to be equal
tmux select-layout -t neuron-test tiled

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

# Attach to the session
print_success "All services started in tmux session!"
print_info ""
print_info "🎯 TMUX LAYOUT:"
print_info "┌─────────────────┬─────────────────┐"
print_info "│ 🟢 SELLER NODE  │ 🔵 BUYER NODE   │"
print_info "│ (port 3001)     │ (port 3002)     │"
print_info "├─────────────────┼─────────────────┤"
print_info "│ 🟢 SELLER CMDS  │ 🔵 BUYER CMDS   │"
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
print_info "🎮 Bottom panes are listening for WebSocket messages"
print_info "📤 Send commands from other terminals to see responses here"
print_info ""
print_status "Attaching to tmux session..."

# Attach to the session
tmux attach-session -t neuron-test
