# Integration Tests

This directory contains integration tests for the Neuron SDK WebSocket wrapper.

## Available Test Scripts

### 1. `test-communication.js` (Recommended)
A comprehensive Node.js test script that provides the most reliable testing experience.

**Features:**
- Starts seller first, then buyer
- Sends P2P messages between nodes
- Checks status of both nodes
- Proper error handling and cleanup
- Colored output for better readability

**Prerequisites:**
```bash
cd integrationtests
npm install
```

**Usage:**
```bash
node test-communication.js
```

### 2. `test-simple.sh`
A simple shell script for basic testing.

**Features:**
- Uses wscat for WebSocket communication
- Basic test flow
- Manual cleanup required

**Prerequisites:**
```bash
npm install -g wscat
```

**Usage:**
```bash
./test-simple.sh
```

### 3. `test-buyer-seller-communication.sh`
A comprehensive shell script with advanced features.

**Features:**
- Detailed logging and error handling
- Automatic cleanup
- Timeout handling
- Colored output

**Prerequisites:**
```bash
npm install -g wscat
```

**Usage:**
```bash
./test-buyer-seller-communication.sh
```

## Test Flow

All scripts follow this general flow:

1. **Start Seller**: Launches the seller node on port 1354 (P2P) and 3001 (WebSocket)
2. **Start Buyer**: Launches the buyer node on port 1355 (P2P) and 3002 (WebSocket)
3. **Wait for Connection**: Allows time for P2P connection to establish
4. **Check Status**: Queries both nodes for their current peer status
5. **Send P2P Messages**: Tests bidirectional P2P communication
6. **Final Status Check**: Verifies final state after communication
7. **Cleanup**: Terminates all processes

## WebSocket Endpoints Tested

### Commands Endpoints
- `ws://localhost:3001/seller/commands` - Seller internal commands
- `ws://localhost:3002/buyer/commands` - Buyer internal commands

### P2P Endpoints
- `ws://localhost:3001/seller/p2p` - Seller P2P communication
- `ws://localhost:3002/buyer/p2p` - Buyer P2P communication

## Commands Tested

### Status Check
```json
{
    "type": "showCurrentPeers",
    "data": "",
    "timestamp": 1234567890123
}
```

### P2P Message
```json
{
    "type": "p2p",
    "data": "Hello from seller to buyer",
    "timestamp": 1234567890123,
    "publicKey": "02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153"
}
```

## Expected Results

A successful test should show:

1. Both seller and buyer start successfully
2. P2P connection is established
3. Status checks return peer information
4. P2P messages are sent and received
5. Final status shows active connections

## Troubleshooting

### Common Issues

1. **Port conflicts**: Make sure ports 3001, 3002, 1354, 1355 are available
2. **Missing dependencies**: Install wscat (`npm install -g wscat`) or Node.js dependencies (`npm install`)
3. **Environment files**: Ensure `.seller-env` and `.buyer-env` are properly configured
4. **Go modules**: Run `go mod tidy` in the parent directory

### Manual Testing

You can also test manually using wscat:

```bash
# Check seller status
echo '{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3001/seller/commands

# Check buyer status  
echo '{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands

# Send P2P message from seller to buyer
echo '{"type":"p2p","data":"Hello","timestamp":'$(date +%s000)',"publicKey":"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153"}' | wscat -c ws://localhost:3001/seller/p2p
```

## Environment Configuration

Make sure your environment files are properly configured:

- `.seller-env` - Contains seller node configuration
- `.buyer-env` - Contains buyer node configuration with seller public key

The buyer's `list_of_sellers` should contain the seller's public key for proper connection.
