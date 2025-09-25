#!/bin/zsh

# Comprehensive test script for buyer-seller communication
# This script:
# 1. Starts the seller first
# 2. Starts the buyer second
# 3. Sends a P2P message from seller to buyer
# 4. Checks status of both buyer and seller
# 5. Cleans up and exits

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SELLER_WS_PORT=3001
BUYER_WS_PORT=3002
SELLER_P2P_PORT=1354
BUYER_P2P_PORT=1355
TEST_MESSAGE="Hello from seller to buyer - test message"
SELLER_PUBLIC_KEY="0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae"
BUYER_PUBLIC_KEY="02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to cleanup processes
cleanup() {
    print_status "Cleaning up processes..."
    
    # Kill seller processes
    kill $(lsof -t -i:$SELLER_WS_PORT) 2>/dev/null || true
    kill $(lsof -t -i:$SELLER_P2P_PORT) 2>/dev/null || true
    
    # Kill buyer processes
    kill $(lsof -t -i:$BUYER_WS_PORT) 2>/dev/null || true
    kill $(lsof -t -i:$BUYER_P2P_PORT) 2>/dev/null || true
    
    # Kill any remaining go processes
    pkill -f "go run.*seller" 2>/dev/null || true
    pkill -f "go run.*buyer" 2>/dev/null || true
    
    print_success "Cleanup completed"
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Function to wait for service to be ready
wait_for_service() {
    local port=$1
    local service_name=$2
    local max_attempts=30
    local attempt=0
    
    print_status "Waiting for $service_name to be ready on port $port..."
    
    while [ $attempt -lt $max_attempts ]; do
        if lsof -i:$port >/dev/null 2>&1; then
            print_success "$service_name is ready on port $port"
            return 0
        fi
        sleep 1
        attempt=$((attempt + 1))
    done
    
    print_error "$service_name failed to start on port $port after $max_attempts seconds"
    return 1
}

# Function to send WebSocket command and get response
send_websocket_command() {
    local ws_url=$1
    local command=$2
    local description=$3
    
    print_status "Sending $description to $ws_url"
    
    # Use wscat to send command and capture response
    response=$(echo "$command" | timeout 10 wscat -c "$ws_url" 2>/dev/null || echo "TIMEOUT")
    
    if [ "$response" = "TIMEOUT" ]; then
        print_error "Timeout waiting for response from $description"
        return 1
    fi
    
    print_success "Response from $description: $response"
    echo "$response"
    return 0
}

# Function to check if wscat is installed
check_wscat() {
    if ! command -v wscat &> /dev/null; then
        print_error "wscat is not installed. Please install it with: npm install -g wscat"
        exit 1
    fi
    print_success "wscat is available"
}

# Main execution
main() {
    print_status "Starting comprehensive buyer-seller communication test"
    print_status "=================================================="
    
    # Check prerequisites
    check_wscat
    
    # Change to project directory
    cd "$(dirname "$0")/.."
    
    # Cleanup any existing processes
    cleanup
    sleep 2
    
    print_status "Step 1: Starting seller..."
    # Start seller in background
    go run . --port=$SELLER_P2P_PORT --mode=peer --buyer-or-seller=seller --envFile=.seller-env --use-local-address --ws-port=$SELLER_WS_PORT &
    SELLER_PID=$!
    
    # Wait for seller to be ready
    if ! wait_for_service $SELLER_WS_PORT "Seller WebSocket"; then
        print_error "Failed to start seller"
        exit 1
    fi
    
    print_status "Step 2: Starting buyer..."
    # Start buyer in background
    go run . --port=$BUYER_P2P_PORT --mode=peer --buyer-or-seller=buyer --list-of-sellers-source=env --envFile=.buyer-env --use-local-address --ws-port=$BUYER_WS_PORT &
    BUYER_PID=$!
    
    # Wait for buyer to be ready
    if ! wait_for_service $BUYER_WS_PORT "Buyer WebSocket"; then
        print_error "Failed to start buyer"
        exit 1
    fi
    
    # Give some time for P2P connection to establish
    print_status "Waiting for P2P connection to establish..."
    sleep 10
    
    print_status "Step 3: Checking seller status..."
    # Check seller status
    seller_status_cmd='{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}'
    send_websocket_command "ws://localhost:$SELLER_WS_PORT/seller/commands" "$seller_status_cmd" "seller status check"
    
    print_status "Step 4: Checking buyer status..."
    # Check buyer status
    buyer_status_cmd='{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}'
    send_websocket_command "ws://localhost:$BUYER_WS_PORT/buyer/commands" "$buyer_status_cmd" "buyer status check"
    
    print_status "Step 5: Sending P2P message from seller to buyer..."
    # Send P2P message from seller to buyer
    p2p_message='{"type":"p2p","data":"'$TEST_MESSAGE'","timestamp":'$(date +%s000)',"publicKey":"'$BUYER_PUBLIC_KEY'"}'
    send_websocket_command "ws://localhost:$SELLER_WS_PORT/seller/p2p" "$p2p_message" "P2P message from seller to buyer"
    
    # Give some time for message to be processed
    sleep 3
    
    print_status "Step 6: Final status check after P2P message..."
    # Check status again after P2P message
    print_status "Checking seller status after P2P message..."
    send_websocket_command "ws://localhost:$SELLER_WS_PORT/seller/commands" "$seller_status_cmd" "seller status check (post-message)"
    
    print_status "Checking buyer status after P2P message..."
    send_websocket_command "ws://localhost:$BUYER_WS_PORT/buyer/commands" "$buyer_status_cmd" "buyer status check (post-message)"
    
    print_status "Step 7: Testing buyer to seller P2P message..."
    # Send P2P message from buyer to seller
    buyer_to_seller_message='{"type":"p2p","data":"Hello from buyer to seller - response message","timestamp":'$(date +%s000)',"publicKey":"'$SELLER_PUBLIC_KEY'"}'
    send_websocket_command "ws://localhost:$BUYER_WS_PORT/buyer/p2p" "$buyer_to_seller_message" "P2P message from buyer to seller"
    
    # Give some time for message to be processed
    sleep 3
    
    print_status "Step 8: Final comprehensive status check..."
    # Final status check
    print_status "Final seller status check..."
    send_websocket_command "ws://localhost:$SELLER_WS_PORT/seller/commands" "$seller_status_cmd" "final seller status check"
    
    print_status "Final buyer status check..."
    send_websocket_command "ws://localhost:$BUYER_WS_PORT/buyer/commands" "$buyer_status_cmd" "final buyer status check"
    
    print_success "=================================================="
    print_success "Test completed successfully!"
    print_success "All communication tests passed:"
    print_success "✓ Seller started and ready"
    print_success "✓ Buyer started and ready"
    print_success "✓ P2P message sent from seller to buyer"
    print_success "✓ P2P message sent from buyer to seller"
    print_success "✓ Status checks completed for both nodes"
    print_success "=================================================="
    
    # Give a moment to see the final output
    sleep 2
}

# Run main function
main "$@"
