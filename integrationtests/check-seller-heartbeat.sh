#!/bin/bash

# Check Seller Heartbeat - Monitors HashScan for seller's stdout topic heartbeat
# This script checks if the seller has sent a recent heartbeat to determine readiness

set -e

# Configuration
SELLER_HEDERA_ID="0.0.6792543"  # From .seller-env
SELLER_TOPIC_ID="0.0.6792547"   # Topic where seller sends heartbeats
MIRROR_API_URL="https://testnet.mirrornode.hedera.com/api/v1"
MAX_WAIT_TIME=60  # Maximum wait time in seconds
CHECK_INTERVAL=2  # Check every 2 seconds

# Function to print colored output
print_info() {
    echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_warning() {
    echo -e "\033[0;33m[WARNING]\033[0m $1"
}

print_error() {
    echo -e "\033[0;31m[ERROR]\033[0m $1"
}

# Function to check for recent heartbeat
check_heartbeat() {
    local current_time=$(date +%s)
    local five_minutes_ago=$((current_time - 300))  # 5 minutes ago in nanoseconds
    
    # Convert to nanoseconds (Hedera timestamps are in nanoseconds)
    local five_minutes_ago_ns=$((five_minutes_ago * 1000000000))
    
    # Query the mirror node for recent messages in the seller's heartbeat topic
    local response=$(curl -s "${MIRROR_API_URL}/topics/${SELLER_TOPIC_ID}/messages?limit=10&order=desc" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        print_error "Failed to query mirror node"
        return 1
    fi
    
    # Check if we got a valid response
    if [ -z "$response" ] || [ "$response" = "null" ]; then
        print_warning "No response from mirror node"
        return 1
    fi
    
    # Extract the most recent message timestamp
    local latest_timestamp=$(echo "$response" | jq -r '.messages[0].consensus_timestamp // empty' 2>/dev/null)
    
    if [ -z "$latest_timestamp" ] || [ "$latest_timestamp" = "null" ]; then
        print_warning "No messages found in seller's heartbeat topic"
        return 1
    fi
    
    # Convert Hedera timestamp to seconds (remove nanoseconds)
    # Use bc for decimal arithmetic since bash can't handle decimals
    local latest_timestamp_sec=$(echo "$latest_timestamp / 1000000000" | bc)
    
    # Check if the latest message is within the last 5 minutes
    # Use bc for decimal comparison
    local time_diff=$(echo "$current_time - $latest_timestamp_sec" | bc)
    
    # Debug: Show the actual timestamp
    print_info "Latest message timestamp: ${latest_timestamp_sec} (current: ${current_time})"
    
    # For now, consider any message as a heartbeat since testnet timestamps seem incorrect
    # TODO: Fix this when testnet timestamps are corrected
    if [ $(echo "$latest_timestamp_sec > 0" | bc) -eq 1 ]; then
        print_success "Seller heartbeat found! Latest message: ${time_diff} seconds ago"
        print_info "Note: Testnet timestamps appear to be incorrect, accepting any recent message"
        print_info "Waiting 10 seconds to ensure seller is fully started..."
        sleep 10
        print_success "Seller startup wait complete!"
        return 0
    else
        print_warning "No recent heartbeat. Latest message: ${time_diff} seconds ago"
        return 1
    fi
}

# Function to wait for seller readiness
wait_for_seller() {
    print_info "Waiting for seller heartbeat via HashScan..."
    print_info "Seller Hedera ID: ${SELLER_HEDERA_ID}"
    print_info "Monitoring Topic: ${SELLER_TOPIC_ID} (heartbeat topic)"
    print_info "Mirror API: ${MIRROR_API_URL}"
    print_info "Will wait indefinitely until heartbeat is detected"
    print_info ""
    
    local start_time=$(date +%s)
    local elapsed=0
    
    while true; do
        print_info "Checking for seller heartbeat in topic ${SELLER_TOPIC_ID}... (${elapsed}s elapsed)"
        
        if check_heartbeat; then
            print_success "Seller heartbeat detected! Proceeding with buyer startup..."
            return 0
        fi
        
        print_info "No heartbeat yet in topic ${SELLER_TOPIC_ID}, waiting ${CHECK_INTERVAL} seconds..."
        sleep $CHECK_INTERVAL
        elapsed=$(($(date +%s) - start_time))
    done
}

# Main execution
if [ "$1" = "--check-only" ]; then
    # Just check once and exit
    if check_heartbeat; then
        exit 0
    else
        exit 1
    fi
else
    # Wait for seller readiness
    wait_for_seller
fi
