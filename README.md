# Neuron Node-RED SDK Wrapper

This project provides a wrapper for the Neuron SDK, enabling seamless integration with Node-RED through WebSocket connections. It implements the P2P communication protocol defined in the Neuron SDK, allowing for real-time data exchange between buyers and sellers.

## Features

- WebSocket endpoints for P2P communication
- Real-time message streaming
- Support for both buyer and seller roles
- Integration with Node-RED
- Secure P2P communication

## Developer preview quick run

0. Create a project structure like this:
```
myfolder/
├── neuron-go-hedera-sdk/    # Checkout destream branch
└── neuron-nodered-sdk-wrapper/  # Checkout main branch
```

1. Clone the repositories:
```bash
# Clone the SDK
git clone -b destream https://github.com/NeuronInnovations/neuron-go-hedera-sdk.git
# Clone the wrapper
git clone https://github.com/NeuronInnovations/neuron-nodered-sdk-wrapper.git
```

2. Configure the environment:
   - Delete the `.template` suffix from `.buyer-env` and `.seller-env`
   - Fill in the required fields in both files

3. Start the services:
```bash
# Start the seller
./integrationtests/start-seller.sh
# Start the buyer
./integrationtests/start-buyer.sh
```

4. Test the connection:
```bash
# Connect to seller WebSocket
wscat -c ws://localhost:3001/seller/p2p
# Connect to buyer WebSocket
wscat -c ws://localhost:3002/buyer/p2p
```

5. Send a test message:
```json
{
    "type": "p2p",
    "data": "Hello from other side",
    "timestamp": 1750079750546,
    "publicKey": "target_peer_public_key"  // Required when sending messages
}
```

## WebSocket Endpoints

The wrapper exposes the following WebSocket endpoints:

### Buyer Endpoint
- `ws://localhost:3002/buyer/p2p` - P2P communication endpoint

### Seller Endpoint
- `ws://localhost:3001/seller/p2p` - P2P communication endpoint

## Message Format

### Sending Messages
```json
{
    "type": "p2p",
    "data": "your message here",
    "timestamp": 1234567890,
    "publicKey": "target_peer_public_key"  // Required when sending messages
}
```

### Receiving Messages
```json
{
    "type": "p2p",
    "data": "received message",
    "timestamp": 1234567890,
    "publicKey": "sender_peer_public_key"  // Included in received messages
}
```

### Error Messages
```json
{
    "type": "error",
    "data": "error description",
    "timestamp": 1234567890,
    "error": "ERROR_CODE"
}
```

## Sending Messages

### Using wscat

For interactive WebSocket testing, you can use wscat:

```bash
# Install wscat
npm install -g wscat

# Connect to buyer P2P endpoint (port 3002)
wscat -c ws://localhost:3002/buyer/p2p

# Connect to seller P2P endpoint (port 3001)
wscat -c ws://localhost:3001/seller/p2p

# Once connected, send a message:
{
    "type": "p2p",
    "data": "Hello from wscat!",
    "timestamp": 1234567890,
    "publicKey": "target_peer_public_key"
}
```

### Using Node-RED

In Node-RED, you can use the WebSocket nodes to connect to these endpoints:

1. Add a WebSocket out node
2. Configure it to connect to:
   - Buyer: `ws://localhost:3002/buyer/p2p`
   - Seller: `ws://localhost:3001/seller/p2p`
3. Set the message format to:
```json
{
    "type": "p2p",
    "data": "{{your message}}",
    "timestamp": {{$timestamp}},
    "publicKey": "{{target_peer_public_key}}"
}
```

## Development Guidelines

1. **Message Format**: Always use the specified JSON format
2. **Error Handling**: Implement proper error handling for all operations
3. **Logging**: Use appropriate logging levels for debugging
4. **Testing**: Test all endpoints before deployment

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Prerequisites

- Go 1.16 or later
- Node-RED installed and running
- A valid Hedera testnet account
- Access to the Neuron Network (registration, DID)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/NeuronInnovations/neuron-nodered-sdk-wrapper.git
cd neuron-nodered-sdk-wrapper
```

2. Install dependencies:
```bash
go mod tidy
```

3. Build the project:
```bash
go build -o nodered-wrapper
```

## Configuration

Create two environment files:

1. `.seller-env` for the seller:
```properties
eth_rpc_url=https://testnet.hashio.io/api
hedera_evm_id=<your-evm-address>
hedera_id=<your-hedera-account-id>
location={"lat":<latitude>,"lon":<longitude>,"alt":0.000000}
mirror_api_url=https://testnet.mirrornode.hedera.com/api/v1
private_key=<your-private-key>
smart_contract_address=0x87e2fc64dc1eae07300c2fc50d6700549e1632ca
```

2. `.buyer-env` for the buyer:
```properties
eth_rpc_url=https://testnet.hashio.io/api
hedera_evm_id=<your-evm-address>
hedera_id=<your-hedera-account-id>
location={"lat":<latitude>,"lon":<longitude>,"alt":0.000000}
mirror_api_url=https://testnet.mirrornode.hedera.com/api/v1
private_key=<your-private-key>
smart_contract_address=0x87e2fc64dc1eae07300c2fc50d6700549e1632ca
list_of_sellers=<seller-public-key>
```

## Running the Service

### 1. Start the Seller

First, start the seller service:

```bash
./nodered-wrapper --mode=peer --buyer-or-seller=seller --envFile=.seller-env --port=20088
```

The seller will start listening for incoming connections and requests.

### 2. Start the Buyer

Then, start the buyer service:

```bash
./nodered-wrapper --mode=peer --buyer-or-seller=buyer --envFile=.buyer-env --port=30088 --list-of-sellers-source=env
```

The buyer will establish a connection with the seller and start the service.
