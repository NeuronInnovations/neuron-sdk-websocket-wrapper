#!/bin/zsh

# iTerm2 split pane test script for buyer-seller communication
# This script creates a single iTerm2 window with 4 split panes

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
}

trap cleanup EXIT

# Check if iTerm2 is available
if ! command -v osascript &> /dev/null || ! osascript -e 'tell application "iTerm" to get version' &> /dev/null; then
    print_error "iTerm2 is not available. Please install iTerm2 or use test-tmux.sh instead"
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

print_status "Starting iTerm2 split-pane buyer-seller test..."
print_info "This will create a single iTerm2 window with 4 split panes:"
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

print_status "Creating iTerm2 window with 4 split panes..."

# Create iTerm2 window with 4 split panes
osascript << EOF
tell application "iTerm"
    -- Create new window
    set newWindow to (create window with default profile)
    
    -- Get the current session
    set currentSession to current session of newWindow
    
    -- Split horizontally (top/bottom)
    tell currentSession
        split horizontally with default profile
    end tell
    
    -- Split the top pane vertically (top-left/top-right)
    tell session 0 of newWindow
        split vertically with default profile
    end tell
    
    -- Split the bottom pane vertically (bottom-left/bottom-right)
    tell session 1 of newWindow
        split vertically with default profile
    end tell
    
    -- Set pane titles and start services
    -- Top-left: Seller Node
    tell session 0 of newWindow
        set name to "🟢 SELLER NODE"
        write text "echo '🟢 SELLER NODE - Starting...'"
        write text "echo 'WebSocket: ws://localhost:3001'"
        write text "echo 'P2P Port: 1354'"
        write text "echo '=============================='"
        write text "cd '$PROJECT_DIR'"
        write text "go run . --port=1354 --mode=peer --buyer-or-seller=seller --envFile=.seller-env --use-local-address --ws-port=3001"
    end tell
    
    -- Top-right: Buyer Node (will start after delay)
    tell session 1 of newWindow
        set name to "🔵 BUYER NODE"
        write text "echo '🔵 BUYER NODE - Waiting for seller...'"
        write text "echo 'WebSocket: ws://localhost:3002'"
        write text "echo 'P2P Port: 1355'"
        write text "echo '=============================='"
        write text "cd '$PROJECT_DIR'"
        write text "sleep 10"
        write text "echo 'Starting buyer node...'"
        write text "go run . --port=1355 --mode=peer --buyer-or-seller=buyer --list-of-sellers-source=env --envFile=.buyer-env --use-local-address --ws-port=3002"
    end tell
    
    -- Bottom-left: Seller Commands
    tell session 2 of newWindow
        set name to "🟢 SELLER CMDS"
        write text "echo '🟢 SELLER COMMANDS TERMINAL'"
        write text "echo '============================'"
        write text "echo 'WebSocket: ws://localhost:3001'"
        write text "echo 'Commands: /seller/commands'"
        write text "echo 'P2P:      /seller/p2p'"
        write text "echo '============================'"
        write text "echo ''"
        write text "echo 'Ready for commands! Copy and paste:'"
        write text "echo ''"
        write text "echo '🔍 Check Status:'"
        write text "echo 'echo \"{\\\"type\\\":\\\"showCurrentPeers\\\",\\\"data\\\":\\\"\\\",\\\"timestamp\\\":\$(date +%s000)}\" | wscat -c ws://localhost:3001/seller/commands'"
        write text "echo ''"
        write text "echo '📤 Send P2P Message:'"
        write text "echo 'echo \"{\\\"type\\\":\\\"p2p\\\",\\\"data\\\":\\\"Hello from seller\\\",\\\"timestamp\\\":\$(date +%s000),\\\"publicKey\\\":\\\"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153\\\"}\" | wscat -c ws://localhost:3001/seller/p2p'"
        write text "echo ''"
    end tell
    
    -- Bottom-right: Buyer Commands
    tell session 3 of newWindow
        set name to "🔵 BUYER CMDS"
        write text "echo '🔵 BUYER COMMANDS TERMINAL'"
        write text "echo '============================'"
        write text "echo 'WebSocket: ws://localhost:3002'"
        write text "echo 'Commands: /buyer/commands'"
        write text "echo 'P2P:      /buyer/p2p'"
        write text "echo '============================'"
        write text "echo ''"
        write text "echo 'Ready for commands! Copy and paste:'"
        write text "echo ''"
        write text "echo '🔍 Check Status:'"
        write text "echo 'echo \"{\\\"type\\\":\\\"showCurrentPeers\\\",\\\"data\\\":\\\"\\\",\\\"timestamp\\\":\$(date +%s000)}\" | wscat -c ws://localhost:3002/buyer/commands'"
        write text "echo ''"
        write text "echo '📤 Send P2P Message:'"
        write text "echo 'echo \"{\\\"type\\\":\\\"p2p\\\",\\\"data\\\":\\\"Hello from buyer\\\",\\\"timestamp\\\":\$(date +%s000),\\\"publicKey\\\":\\\"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae\\\"}\" | wscat -c ws://localhost:3002/buyer/p2p'"
        write text "echo ''"
    end tell
    
    -- Activate the window
    activate
end tell
EOF

print_success "iTerm2 window with 4 split panes created!"
print_info ""
print_info "🎯 ITERM2 LAYOUT:"
print_info "┌─────────────────┬─────────────────┐"
print_info "│ 🟢 SELLER NODE  │ 🔵 BUYER NODE   │"
print_info "│ (port 3001)     │ (port 3002)     │"
print_info "├─────────────────┼─────────────────┤"
print_info "│ 🟢 SELLER CMDS  │ 🔵 BUYER CMDS   │"
print_info "│ (test commands) │ (test commands) │"
print_info "└─────────────────┴─────────────────┘"
print_info ""
print_info "💡 ITERM2 CONTROLS:"
print_info "  Cmd+[ or Cmd+] - Navigate between panes"
print_info "  Cmd+D - Split pane vertically"
print_info "  Cmd+Shift+D - Split pane horizontally"
print_info "  Cmd+W - Close current pane"
print_info ""
print_info "⏱️  Wait for P2P connection to establish (about 10-15 seconds)"
print_info "🎮 Use the bottom panes to test communication"
print_info ""
print_status "iTerm2 window should now be open with all services running!"
