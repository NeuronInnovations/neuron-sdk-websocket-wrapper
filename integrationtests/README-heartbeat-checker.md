# Seller Heartbeat Checker

This tool intelligently monitors the seller's readiness by checking for recent heartbeats in the seller's stdout topic on HashScan, eliminating the need for fixed wait times.

## 🎯 Purpose

Instead of waiting a fixed amount of time (like 10 seconds) for the seller to start up, this tool:
- Queries the Hedera mirror node for the seller's stdout topic
- Checks for recent heartbeat messages
- Determines when the seller is actually ready
- Proceeds with buyer startup only when seller is confirmed ready

## 📁 Files

| File | Platform | Description |
|------|----------|-------------|
| `check-seller-heartbeat.sh` | **Unix/Linux/macOS** | Bash script for heartbeat checking |
| `check-seller-heartbeat.bat` | **Windows** | Batch script for heartbeat checking |

## 🚀 Usage

### Unix/Linux/macOS
```bash
# Check once and exit
./check-seller-heartbeat.sh --check-only

# Wait for seller readiness (used by tmux script)
./check-seller-heartbeat.sh
```

### Windows
```batch
# Double-click to run, or:
check-seller-heartbeat.bat
```

## 🔧 Configuration

The heartbeat checker uses these settings (configurable in the scripts):

```bash
SELLER_HEDERA_ID="0.0.6792543"  # From .seller-env
MIRROR_API_URL="https://testnet.mirrornode.hedera.com/api/v1"
MAX_WAIT_TIME=60  # Maximum wait time in seconds
CHECK_INTERVAL=2  # Check every 2 seconds
```

## 🧠 How It Works

### 1. **Query Mirror Node**
- Queries the Hedera mirror node API for the seller's stdout topic
- Gets the 10 most recent messages ordered by timestamp

### 2. **Check Timestamp**
- Extracts the most recent message timestamp
- Converts Hedera nanosecond timestamps to seconds
- Checks if the message is within the last 5 minutes

### 3. **Determine Readiness**
- ✅ **Ready**: Recent heartbeat found (within 5 minutes)
- ⚠️ **Not Ready**: No recent heartbeat or no messages
- ⏱️ **Timeout**: Waits up to 60 seconds, then proceeds anyway

## 📊 Output Examples

### Seller Ready
```
[INFO] Checking seller readiness via HashScan heartbeat...
[SUCCESS] Seller heartbeat found! Latest message: 23 seconds ago
[SUCCESS] Seller is ready! Proceeding with buyer startup...
```

### No Recent Heartbeat
```
[INFO] Checking seller readiness via HashScan heartbeat...
[WARNING] No recent heartbeat. Latest message: 342 seconds ago
[WARNING] Seller heartbeat not detected, but proceeding anyway...
```

### No Messages
```
[INFO] Checking seller readiness via HashScan heartbeat...
[WARNING] No messages found in seller's stdout topic
[WARNING] Seller heartbeat not detected, but proceeding anyway...
```

## 🔗 Integration with Tmux Script

The `test-tmux.sh` script now uses the heartbeat checker:

```bash
# Old way (fixed wait):
print_status "Waiting 10 seconds for seller to initialize..."
sleep 10

# New way (smart wait):
print_status "Checking seller readiness via HashScan heartbeat..."
if ./check-seller-heartbeat.sh; then
    print_success "Seller is ready! Starting buyer..."
else
    print_warning "Seller heartbeat not detected, but proceeding anyway..."
fi
```

## 🛠️ Dependencies

### Unix/Linux/macOS
- `curl` - For HTTP requests to mirror node
- `jq` - For JSON parsing
- `bash` - Shell environment

### Windows
- `curl` - For HTTP requests to mirror node
- `jq` - For JSON parsing
- `powershell` - For timestamp calculations

## 📋 Installation

### macOS
```bash
# Install dependencies
brew install curl jq

# Make script executable
chmod +x check-seller-heartbeat.sh
```

### Ubuntu/Debian
```bash
# Install dependencies
sudo apt-get install curl jq

# Make script executable
chmod +x check-seller-heartbeat.sh
```

### Windows
```batch
# Install dependencies (using Chocolatey)
choco install curl jq

# Or download manually:
# curl: https://curl.se/download.html
# jq: https://stedolan.github.io/jq/download/
```

## 🎯 Benefits

1. **Faster Startup**: No unnecessary waiting when seller is ready quickly
2. **More Reliable**: Actually checks if seller is ready, not just time-based
3. **Better UX**: Clear feedback about seller status
4. **Robust**: Falls back gracefully if heartbeat check fails
5. **Configurable**: Easy to adjust wait times and check intervals

## 🔍 Troubleshooting

### "No messages found in seller's stdout topic"
- **Cause**: Seller hasn't started yet or isn't sending heartbeats
- **Solution**: Start the seller first, then run the heartbeat checker

### "Failed to query mirror node"
- **Cause**: Network issues or mirror node is down
- **Solution**: Check internet connection and mirror node status

### "curl: command not found"
- **Cause**: curl is not installed
- **Solution**: Install curl using your package manager

### "jq: command not found"
- **Cause**: jq is not installed
- **Solution**: Install jq using your package manager

## 🎉 Success Criteria

The heartbeat checker is working correctly when:
1. ✅ It detects recent heartbeats when seller is running
2. ✅ It reports no heartbeats when seller is not running
3. ✅ It times out gracefully after 60 seconds
4. ✅ It integrates seamlessly with the tmux script
5. ✅ It provides clear, colored output for easy reading

