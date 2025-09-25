# WSCAT Commands for Neuron SDK Testing

Connect to the WebSocket URL, then type the JSON command.

---

## 🔍 COMMANDS MODE

### ws://localhost:3001/seller/commands
type
```json
{"type":"showCurrentPeers","data":"","timestamp":1758815486000}
```

### ws://localhost:3002/buyer/commands
type
```json
{"type":"showCurrentPeers","data":"","timestamp":1758815486000}
```

### ws://localhost:3002/buyer/commands (Replace Sellers)
type
```json
{"type":"replaceSellers","data":"{\"sellerPublicKeys\":[\"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae\"]}","timestamp":1758815486000}
```

---

## 📤 P2P MODE

### ws://localhost:3001/seller/p2p (Send to Buyer)
type
```json
{"type":"p2p","data":"Hello from seller to buyer","timestamp":1758815486000,"publicKey":"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153"}
```

### ws://localhost:3002/buyer/p2p (Send to Seller)
type
```json
{"type":"p2p","data":"Hello from buyer to seller","timestamp":1758815486000,"publicKey":"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae"}
```

### ws://localhost:3001/seller/p2p (Custom Message)
type
```json
{"type":"p2p","data":"Your custom message here","timestamp":1758815486000,"publicKey":"02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153"}
```

### ws://localhost:3002/buyer/p2p (Custom Message)
type
```json
{"type":"p2p","data":"Your custom message here","timestamp":1758815486000,"publicKey":"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae"}
```

---

## 🔧 Configuration

- **Seller Public Key**: `0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae`
- **Buyer Public Key**: `02c7370bf416ee6e9f9a430a12869c456d93db6b7392a9f90d0db8981190f47153`
- **Update timestamp**: Replace `1758815486000` with current timestamp
