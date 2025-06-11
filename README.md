# Neuron Node-RED SDK Wrapper

Neuron Node-RED SDK Wrapper is a service that facilitates secure communication between buyers and sellers in the Neuron Network. It acts as a bridge between Node-RED clients and the Neuron Network's P2P infrastructure, handling connection establishment, message routing, and payment processing.

## Features

- Seamless Node-RED integration for Neuron Network communication
- Automatic connection management using seller public keys
- Support for both regular HTTP and Server-Sent Events (SSE)
- Secure P2P communication using libp2p
- Integration with Hedera for payment processing

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
