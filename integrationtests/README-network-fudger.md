# Network Fudger Scripts

These scripts help you test the comprehensive error reporting system by simulating network failures between the seller and buyer.

## 🎯 Purpose

The network fudger blocks the seller from connecting to the buyer, allowing you to test:
- Comprehensive error reporting
- Network failure diagnostics
- Troubleshooting suggestions
- Hedera self-error topic integration

## 📁 Scripts

### Core Scripts

| Script | Purpose | Description |
|--------|---------|-------------|
| `network-fudger-on.sh` | **Activate** | Blocks seller → buyer connections on port 1355 |
| `network-fudger-off.sh` | **Deactivate** | Restores normal seller → buyer connectivity |
| `network-fudger-status.sh` | **Check Status** | Shows current firewall state and blocking status |

### Test Scripts

| Script | Purpose | Description |
|--------|---------|-------------|
| `test-error-reporting.sh` | **Full Test** | Complete workflow to test error reporting system |

## 🚀 Quick Start

### 1. Check Current Status
```bash
./network-fudger-status.sh
```

### 2. Activate Network Fudger
```bash
./network-fudger-on.sh
```

### 3. Test Error Reporting
```bash
./test-error-reporting.sh
```

### 4. Deactivate Network Fudger
```bash
./network-fudger-off.sh
```

## 🧪 Testing Workflow

### Manual Testing
1. **Start Buyer**: `go run . --port=1355 --mode=peer --buyer-or-seller=buyer --list-of-sellers-source=env --envFile=.buyer-env --use-local-address --ws-port=3002`
2. **Activate Fudger**: `./network-fudger-on.sh`
3. **Start Seller**: `go run . --port=3001 --mode=peer --buyer-or-seller=seller --envFile=.seller-env --use-local-address --ws-port=3001`
4. **Check Error Reports**: Look in your Hedera self-error topic
5. **Deactivate Fudger**: `./network-fudger-off.sh`

### Automated Testing
```bash
./test-error-reporting.sh
```

## 🔍 What You'll See

When the network fudger is active, the seller will fail to connect to the buyer and generate comprehensive error reports including:

```
DIAL FAILURE ANALYSIS:
Target Peer ID: [buyer-peer-id]
My Peer ID: [seller-peer-id]
Role: SERVER (Seller)
Error: [detailed error message]
Target Addresses: [buyer addresses]
My Addresses: [seller addresses]
Network Analysis:
  Connected Peers: [count]
  Open Connections: [count]
  Target Connection Status: [status]
Error Analysis:
  - CONNECTION REFUSED: Target is not listening
  - Possible causes: Service not running, wrong port, firewall blocking
Troubleshooting Suggestions:
  1. Check firewall settings on both sides
  2. Verify NAT configuration and port forwarding
  3. Test network connectivity with ping/telnet
  4. Check if target service is running
  5. Verify port numbers and addresses
```

## 🛡️ How It Works

### macOS (pfctl)
- Creates temporary firewall rules blocking port 1355
- Uses `pfctl` to load/unload rules
- Automatically detects macOS and uses appropriate commands

### Linux (iptables)
- Adds/removes iptables rules blocking port 1355
- Uses `iptables` for firewall management
- Automatically detects Linux and uses appropriate commands

## ⚠️ Important Notes

1. **Requires sudo**: These scripts need root privileges to modify firewall rules
2. **Port 1355**: Specifically blocks the buyer's port (1355)
3. **Reversible**: All changes can be easily undone
4. **Safe**: Only blocks specific ports, doesn't affect other network traffic

## 🔧 Troubleshooting

### Script Fails to Run
- Ensure you have sudo privileges
- Check if `pfctl` (macOS) or `iptables` (Linux) is available
- Verify you're running from the `integrationtests` directory

### Fudger Not Working
- Check status: `./network-fudger-status.sh`
- Verify the correct port is being blocked
- Check if other firewall software is interfering

### Error Reports Not Appearing
- Verify Hedera connection is working
- Check if the seller is actually attempting to connect
- Look for any other error messages in the logs

## 📊 Expected Results

### With Fudger ON
- ✅ Buyer starts successfully
- ❌ Seller fails to connect to buyer
- 📝 Comprehensive error reports sent to Hedera
- 🔍 Detailed network analysis in error reports

### With Fudger OFF
- ✅ Buyer starts successfully
- ✅ Seller connects to buyer successfully
- ✅ Normal P2P communication works
- 📝 No error reports (normal operation)

## 🎉 Success Criteria

The test is successful when:
1. Network fudger blocks seller → buyer connection
2. Comprehensive error reports appear in Hedera self-error topic
3. Error reports include detailed network analysis
4. Error reports include troubleshooting suggestions
5. Network fudger can be deactivated to restore normal operation
