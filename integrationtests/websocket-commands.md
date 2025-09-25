# WebSocket Commands for Neuron SDK Testing

This file contains all the WebSocket commands you can copy and paste into separate terminals to test the buyer-seller communication in your tmux sessions.

## 🎯 Quick Reference

- **Seller WebSocket**: `ws://localhost:3001`
- **Buyer WebSocket**: `ws://localhost:3002`
- **Commands Endpoint**: `/seller/commands` or `/buyer/commands`
- **P2P Endpoint**: `/seller/p2p` or `/buyer/p2p`

---

## 🔍 Status Commands

### Check Seller Status
```bash
echo '{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3001/seller/commands
```

### Check Buyer Status
```bash
echo '{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands
```

---

## 📤 P2P Communication Commands

### Send Message from Seller to Buyer
```bash
echo '{"type":"p2p","data":"Hello from seller to buyer","timestamp":'$(date +%s000)',"publicKey":"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153"}' | wscat -c ws://localhost:3001/seller/p2p
```

### Send Message from Buyer to Seller
```bash
echo '{"type":"p2p","data":"Hello from buyer to seller","timestamp":'$(date +%s000)',"publicKey":"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae"}' | wscat -c ws://localhost:3002/buyer/p2p
```

### Send Custom Message from Seller
```bash
echo '{"type":"p2p","data":"Your custom message here","timestamp":'$(date +%s000)',"publicKey":"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153"}' | wscat -c ws://localhost:3001/seller/p2p
```

### Send Custom Message from Buyer
```bash
echo '{"type":"p2p","data":"Your custom message here","timestamp":'$(date +%s000)',"publicKey":"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae"}' | wscat -c ws://localhost:3002/buyer/p2p
```

---

## 🔄 Seller Management Commands (Buyer Only)

### Replace Sellers (Buyer Only)
```bash
echo '{"type":"replaceSellers","data":"{\"sellerPublicKeys\":[\"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae\"]}","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands
```

### Replace Multiple Sellers (Buyer Only)
```bash
echo '{"type":"replaceSellers","data":"{\"sellerPublicKeys\":[\"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae\",\"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153\"]}","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands
```

---

## 🧪 Test Scenarios

### Scenario 1: Basic Status Check
1. **Check seller status**:
   ```bash
   echo '{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3001/seller/commands
   ```

2. **Check buyer status**:
   ```bash
   echo '{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands
   ```

### Scenario 2: P2P Communication Test
1. **Send message from seller to buyer**:
   ```bash
   echo '{"type":"p2p","data":"Test message from seller","timestamp":'$(date +%s000)',"publicKey":"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153"}' | wscat -c ws://localhost:3001/seller/p2p
   ```

2. **Send response from buyer to seller**:
   ```bash
   echo '{"type":"p2p","data":"Response from buyer","timestamp":'$(date +%s000)',"publicKey":"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae"}' | wscat -c ws://localhost:3002/buyer/p2p
   ```

### Scenario 3: Seller Management (Buyer Only)
1. **Check current sellers**:
   ```bash
   echo '{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands
   ```

2. **Replace sellers**:
   ```bash
   echo '{"type":"replaceSellers","data":"{\"sellerPublicKeys\":[\"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae\"]}","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands
   ```

---

## 📋 Command Templates

### Status Check Template
```bash
echo '{"type":"showCurrentPeers","data":"","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:PORT/ROLE/commands
```

### P2P Message Template
```bash
echo '{"type":"p2p","data":"MESSAGE_TEXT","timestamp":'$(date +%s000)',"publicKey":"TARGET_PUBLIC_KEY"}' | wscat -c ws://localhost:PORT/ROLE/p2p
```

### Replace Sellers Template (Buyer Only)
```bash
echo '{"type":"replaceSellers","data":"{\"sellerPublicKeys\":[\"SELLER_PUBLIC_KEY\"]}","timestamp":'$(date +%s000)'}' | wscat -c ws://localhost:3002/buyer/commands
```

---

## 🔧 Configuration Values

### Ports
- **Seller WebSocket**: `3001`
- **Buyer WebSocket**: `3002`
- **Seller P2P**: `1354`
- **Buyer P2P**: `1355`

### Public Keys
- **Seller Public Key**: `0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae`
- **Buyer Public Key**: `02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153`

### Endpoints
- **Commands**: `/seller/commands` or `/buyer/commands`
- **P2P**: `/seller/p2p` or `/buyer/p2p`

---

## 💡 Usage Tips

1. **Copy the entire command** including the `echo` and `wscat` parts
2. **Paste into a separate terminal** (not the tmux session)
3. **Watch the tmux bottom panes** for responses
4. **Use `$(date +%s000)` for timestamps** - it generates current timestamp in milliseconds
5. **Check the tmux top panes** for node status and connection info

---

## 🚨 Error Handling

### Common Errors
- **Connection refused**: Make sure the nodes are running
- **Invalid JSON**: Check the command syntax
- **Timeout**: Wait for P2P connection to establish (10-15 seconds)

### Troubleshooting
1. **Check if nodes are running** in the tmux top panes
2. **Verify ports are correct** (3001 for seller, 3002 for buyer)
3. **Wait for P2P connection** to establish before sending messages
4. **Check the tmux bottom panes** for WebSocket connection status

---

## 📝 Notes

- **Seller commands** work on port 3001
- **Buyer commands** work on port 3002
- **P2P messages** require the target peer's public key
- **Replace sellers** command only works for buyers
- **Timestamps** are automatically generated using `$(date +%s000)`
- **Responses** will appear in the tmux bottom panes (wscat listeners)
