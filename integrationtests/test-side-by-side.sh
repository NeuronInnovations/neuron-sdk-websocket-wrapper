#!/bin/zsh

# Side-by-side test script for buyer-seller communication
# This script opens two separate terminal windows for visual side-by-side testing
# Supports both Terminal.app and iTerm2

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

print_command() {
    echo -e "${CYAN}[COMMAND]${NC} $1"
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
    rm -f /tmp/seller_terminal.sh /tmp/buyer_terminal.sh /tmp/seller_commands.sh /tmp/buyer_commands.sh
}

trap cleanup EXIT

# Check if wscat is installed
if ! command -v wscat &> /dev/null; then
    print_error "wscat is not installed. Install with: npm install -g wscat"
    exit 1
fi

# Change to project directory
PROJECT_DIR="$(dirname "$0")/.."
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
cd "$PROJECT_DIR"

print_status "Starting side-by-side buyer-seller test..."
print_info "This will open four terminal windows:"
print_info "  Top Left:     🟢 SELLER NODE (port 3001)"
print_info "  Top Right:    🔵 BUYER NODE  (port 3002)"
print_info "  Bottom Left:  🟢 SELLER COMMANDS"
print_info "  Bottom Right: 🔵 BUYER COMMANDS"

# Cleanup first
cleanup
sleep 2

# Create temporary scripts for each terminal
SELLER_SCRIPT="/tmp/seller_terminal.sh"
BUYER_SCRIPT="/tmp/buyer_terminal.sh"
SELLER_COMMANDS_SCRIPT="/tmp/seller_commands.sh"
BUYER_COMMANDS_SCRIPT="/tmp/buyer_commands.sh"

# Create seller terminal script
cat > "$SELLER_SCRIPT" << EOF
#!/bin/zsh
cd "$PROJECT_DIR"
clear
echo "🟢 SELLER TERMINAL"
echo "=================="
echo "WebSocket: ws://localhost:3001"
echo "P2P Port: 1354"
echo "Project Dir: $PROJECT_DIR"
echo "=================="
echo ""
echo "Starting seller node..."
echo ""

# Start the seller
go run . --port=1354 --mode=peer --buyer-or-seller=seller --envFile=.seller-env --use-local-address --ws-port=3001

echo ""
echo "🟢 SELLER TERMINAL - Exited"
read -p "Press Enter to close this window..."
EOF

# Create buyer terminal script  
cat > "$BUYER_SCRIPT" << EOF
#!/bin/zsh
cd "$PROJECT_DIR"
clear
echo "🔵 BUYER TERMINAL"
echo "=================="
echo "WebSocket: ws://localhost:3002"
echo "P2P Port: 1355"
echo "Project Dir: $PROJECT_DIR"
echo "=================="
echo ""
echo "Starting buyer node..."
echo ""

# Start the buyer
go run . --port=1355 --mode=peer --buyer-or-seller=buyer --list-of-sellers-source=env --envFile=.buyer-env --use-local-address --ws-port=3002

echo ""
echo "🔵 BUYER TERMINAL - Exited"
read -p "Press Enter to close this window..."
EOF

# Create seller commands script
cat > "$SELLER_COMMANDS_SCRIPT" << EOF
#!/bin/zsh
clear
echo "🟢 SELLER COMMANDS TERMINAL"
echo "============================"
echo "WebSocket: ws://localhost:3001"
echo "Commands: /seller/commands"
echo "P2P:      /seller/p2p"
echo "============================"
echo ""
echo "Ready for commands! Copy and paste the commands below:"
echo ""
echo "🔍 Check Status:"
echo "echo '{\"type\":\"showCurrentPeers\",\"data\":\"\",\"timestamp\":'$(date +%s000)'}' | wscat -c ws://localhost:3001/seller/commands"
echo ""
echo "📤 Send P2P Message:"
echo "echo '{\"type\":\"p2p\",\"data\":\"Hello from seller\",\"timestamp\":'$(date +%s000)',\"publicKey\":\"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153\"}' | wscat -c ws://localhost:3001/seller/p2p"
echo ""
echo "Press Ctrl+C to close this window"
echo ""

# Start an interactive shell
exec zsh
EOF

# Create buyer commands script
cat > "$BUYER_COMMANDS_SCRIPT" << EOF
#!/bin/zsh
clear
echo "🔵 BUYER COMMANDS TERMINAL"
echo "============================"
echo "WebSocket: ws://localhost:3002"
echo "Commands: /buyer/commands"
echo "P2P:      /buyer/p2p"
echo "============================"
echo ""
echo "Ready for commands! Copy and paste the commands below:"
echo ""
echo "🔍 Check Status:"
echo "echo '{\"type\":\"showCurrentPeers\",\"data\":\"\",\"timestamp\":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands"
echo ""
echo "📤 Send P2P Message:"
echo "echo '{\"type\":\"p2p\",\"data\":\"Hello from buyer\",\"timestamp\":'$(date +%s000)',\"publicKey\":\"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae\"}' | wscat -c ws://localhost:3002/buyer/p2p"
echo ""
echo "Press Ctrl+C to close this window"
echo ""

# Start an interactive shell
exec zsh
EOF

chmod +x "$SELLER_SCRIPT"
chmod +x "$BUYER_SCRIPT"
chmod +x "$SELLER_COMMANDS_SCRIPT"
chmod +x "$BUYER_COMMANDS_SCRIPT"

# Check if iTerm2 is available
if command -v osascript &> /dev/null && osascript -e 'tell application "iTerm" to get version' &> /dev/null; then
    print_info "Using iTerm2 for better window management..."
    
    # Create iTerm2 session with 4 panes
    osascript << EOF
tell application "iTerm"
    create window with default profile
    tell current session of current window
        set name to "🟢 SELLER NODE"
        write text "'$SELLER_SCRIPT'"
    end tell
    
    delay 10
    
    tell current window
        create tab with default profile
        tell current session
            set name to "🔵 BUYER NODE"
            write text "'$BUYER_SCRIPT'"
        end tell
    end tell
    
    delay 2
    
    tell current window
        create tab with default profile
        tell current session
            set name to "🟢 SELLER CMDS"
            write text "'$SELLER_COMMANDS_SCRIPT'"
        end tell
    end tell
    
    tell current window
        create tab with default profile
        tell current session
            set name to "🔵 BUYER CMDS"
            write text "'$BUYER_COMMANDS_SCRIPT'"
        end tell
    end tell
    
    activate
end tell
EOF

else
    print_info "Using Terminal.app..."
    
    print_status "Opening SELLER NODE terminal window (top left)..."
    # Open seller terminal (top left)
    osascript -e "tell application \"Terminal\" to do script \"'$SELLER_SCRIPT'\""
    
    print_status "Waiting 10 seconds for seller to initialize..."
    sleep 10
    
    print_status "Opening BUYER NODE terminal window (top right)..."
    # Open buyer terminal (top right)  
    osascript -e "tell application \"Terminal\" to do script \"'$BUYER_SCRIPT'\""
    
    sleep 2
    
    print_status "Opening SELLER COMMANDS terminal window (bottom left)..."
    # Open seller commands terminal (bottom left)
    osascript -e "tell application \"Terminal\" to do script \"'$SELLER_COMMANDS_SCRIPT'\""
    
    print_status "Opening BUYER COMMANDS terminal window (bottom right)..."
    # Open buyer commands terminal (bottom right)
    osascript -e "tell application \"Terminal\" to do script \"'$BUYER_COMMANDS_SCRIPT'\""
fi

print_success "All four terminals opened!"
echo ""
print_info "🎯 TERMINAL LAYOUT:"
print_info "┌─────────────────┬─────────────────┐"
print_info "│ 🟢 SELLER NODE  │ 🔵 BUYER NODE   │"
print_info "│ (port 3001)     │ (port 3002)     │"
print_info "├─────────────────┼─────────────────┤"
print_info "│ 🟢 SELLER CMDS  │ 🔵 BUYER CMDS   │"
print_info "│ (test commands) │ (test commands) │"
print_info "└─────────────────┴─────────────────┘"
echo ""
print_info "💡 The command terminals show ready-to-copy commands!"
print_info "⏱️  Wait for P2P connection to establish (about 10-15 seconds)"
print_info "🎮 Use the bottom terminals to test communication"
echo ""
print_status "Press Ctrl+C to cleanup and close all windows"
print_info "Or close the terminal windows manually"

# Wait for user to stop
while true; do
    sleep 1
done
