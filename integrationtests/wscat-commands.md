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
{"type":"p2p","data":"Hello from seller to buyer","timestamp":1758815486000,"publicKey":"03f1f67332e6ef558c198c8bc650bd15a2923ee4199b909bb1768c2af9ad9cd455"}
```

### ws://localhost:3002/buyer/p2p (Send to Seller)
type
```json
{"type":"p2p","data":"Hello from buyer to seller","timestamp":1758815486000,"publicKey":"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae"}
```

### ws://localhost:3001/seller/p2p (Custom Message)
type
```json
{"type":"p2p","data":"Your custom message here","timestamp":1758815486000,"publicKey":"03f1f67332e6ef558c198c8bc650bd15a2923ee4199b909bb1768c2af9ad9cd455"}
```

### ws://localhost:3002/buyer/p2p (Custom Message)
type
```json
{"type":"p2p","data":"Your custom message here","timestamp":1758815486000,"publicKey":"0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae"}
```

---

## 🔧 Configuration

- **Seller Public Key**: `0278b309d9b02ade112cdda215cd79da90916c940359cce783ae0b1779135f85ae`
- **Buyer Public Key**: `03f1f67332e6ef558c198c8bc650bd15a2923ee4199b909bb1768c2af9ad9cd455`
- **Update timestamp**: Replace `1758815486000` with current timestamp
                   

                                     