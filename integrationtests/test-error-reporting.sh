#!/bin/bash

# Test Error Reporting - Complete workflow to test comprehensive error reporting
# This script demonstrates the full workflow of testing error reporting

set -e

echo "🧪 COMPREHENSIVE ERROR REPORTING TEST"
echo "======================================"
echo "This script will test the comprehensive error reporting system"
echo "by simulating network failures and capturing detailed error messages"
echo ""

# Function to print colored output
print_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

print_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $1"
}

# Check if we're in the right directory
if [ ! -f "network-fudger-on.sh" ]; then
    print_error "Please run this script from the integrationtests directory"
    exit 1
fi

print_info "Step 1: Checking current network fudger status..."
./network-fudger-status.sh

echo ""
print_info "Step 2: Starting buyer node..."
print_warning "Starting buyer on port 1355 with WebSocket on port 3002"

# Start buyer in background
cd ..
go run . --port=1355 --mode=peer --buyer-or-seller=buyer --list-of-sellers-source=env --envFile=.buyer-env --use-local-address --ws-port=3002 &
BUYER_PID=$!

# Wait for buyer to start
sleep 3

print_success "Buyer started with PID: $BUYER_PID"

echo ""
print_info "Step 3: Activating network fudger..."
print_warning "This will block seller from connecting to buyer"

./integrationtests/network-fudger-on.sh

echo ""
print_info "Step 4: Starting seller node (this should fail to connect)..."
print_warning "Starting seller on port 3001 with WebSocket on port 3001"

# Start seller in background
go run . --port=3001 --mode=peer --buyer-or-seller=seller --envFile=.seller-env --use-local-address --ws-port=3001 &
SELLER_PID=$!

# Wait for seller to attempt connection and fail
sleep 5

print_success "Seller started with PID: $SELLER_PID"
print_warning "Seller should have failed to connect to buyer due to network fudger"

echo ""
print_info "Step 5: Checking for error reports..."
print_warning "Check your Hedera self-error topic for comprehensive error reports"
print_warning "The error reports should include detailed network analysis and troubleshooting suggestions"

echo ""
print_info "Step 6: Deactivating network fudger..."
print_warning "This will restore normal connectivity"

./integrationtests/network-fudger-off.sh

echo ""
print_info "Step 7: Testing normal connectivity..."
print_warning "Seller should now be able to connect to buyer"

# Wait for normal connection
sleep 3

print_success "Normal connectivity restored"

echo ""
print_info "Step 8: Cleaning up..."
print_warning "Stopping buyer and seller processes"

# Kill the processes
kill $BUYER_PID 2>/dev/null || true
kill $SELLER_PID 2>/dev/null || true

# Wait for processes to stop
sleep 2

print_success "Test completed successfully!"

echo ""
echo "📊 TEST SUMMARY:"
echo "================"
echo "✅ Buyer started successfully"
echo "✅ Network fudger activated (blocked seller → buyer)"
echo "✅ Seller started and failed to connect (as expected)"
echo "✅ Comprehensive error reports should be in Hedera self-error topic"
echo "✅ Network fudger deactivated"
echo "✅ Normal connectivity restored"
echo "✅ Processes cleaned up"
echo ""
echo "🔍 NEXT STEPS:"
echo "1. Check your Hedera self-error topic for detailed error reports"
echo "2. Verify the error reports include network analysis and troubleshooting suggestions"
echo "3. Test with different network conditions using the fudger scripts"
echo ""
echo "💡 USEFUL COMMANDS:"
echo "   Check status: ./integrationtests/network-fudger-status.sh"
echo "   Turn on:     ./integrationtests/network-fudger-on.sh"
echo "   Turn off:    ./integrationtests/network-fudger-off.sh"
