package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"time"

	neuronsdk "github.com/NeuronInnovations/neuron-go-hedera-sdk" // Import neuronFactory from neuron-go-sdk
	commonlib "github.com/NeuronInnovations/neuron-go-hedera-sdk/common-lib"
	hedera_msg "github.com/NeuronInnovations/neuron-go-hedera-sdk/hedera"
	"github.com/NeuronInnovations/neuron-go-hedera-sdk/types"
	"github.com/gorilla/websocket"
	"github.com/hashgraph/hedera-sdk-go/v2"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/protocol"
	"github.com/spf13/pflag"
)

var (
	Protocol = protocol.ID(*pflag.String("protocol", "nrn-nodered/v1", "Protocol ID for the neuron network"))
	WSPort   = pflag.Int("ws-port", 8080, "WebSocket server port")
)

// WebSocket message structure
type WSMessage struct {
	Type      string      `json:"type"`
	Data      interface{} `json:"data"`
	Timestamp int64       `json:"timestamp"`
}

// WebSocket upgrader
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // In production, implement proper origin checking
	},
}

// Handle WebSocket connections
func handleWebSocket(w http.ResponseWriter, r *http.Request, messageChan chan WSMessage) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Failed to upgrade connection: %v", err)
		return
	}
	defer conn.Close()

	// Handle incoming messages
	go func() {
		for {
			var msg WSMessage
			err := conn.ReadJSON(&msg)
			if err != nil {
				log.Printf("Error reading message: %v", err)
				return
			}
			messageChan <- msg
		}
	}()

	// Send messages to client
	for msg := range messageChan {
		err := conn.WriteJSON(msg)
		if err != nil {
			log.Printf("Error writing message: %v", err)
			return
		}
	}
}

// Handle P2P messages from WebSocket and forward to peers
func handleP2PMessages(ctx context.Context, b *commonlib.NodeBuffers, messageChan chan WSMessage) {
	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case msg := <-messageChan:
				// Convert message to bytes
				msgBytes := []byte(msg.Data.(string) + "\n")

				// Send to all connected peers
				for peerID, bufferInfo := range b.GetBufferMap() {
					log.Printf("Sending message to peer %s\n", peerID)

					// Send the message using the p2p stream
					sendError := commonlib.WriteAndFlushBuffer(*bufferInfo, peerID, b, msgBytes)
					if sendError != nil {
						// Send the public connectivity error message for the other peer's sdk to handle
						hedera_msg.PeerSendErrorMessage(
							bufferInfo.RequestOrResponse.OtherStdInTopic,
							types.WriteError,
							"Failed to send message: "+sendError.Error(),
							types.SendFreshHederaRequest,
						)
						log.Printf("Error sending to peer %s: %v\n", peerID, sendError)
						continue
					}
					log.Printf("Successfully sent message to peer %s\n", peerID)
				}
			}
		}
	}()
}

func main() {
	// Parse command line flags
	pflag.Parse()

	// Create channels for P2P messages
	buyerP2PChan := make(chan WSMessage)
	sellerP2PChan := make(chan WSMessage)

	// Set up HTTP routes for P2P
	http.HandleFunc("/buyer/p2p", func(w http.ResponseWriter, r *http.Request) {
		handleWebSocket(w, r, buyerP2PChan)
	})
	http.HandleFunc("/seller/p2p", func(w http.ResponseWriter, r *http.Request) {
		handleWebSocket(w, r, sellerP2PChan)
	})

	// Start HTTP server
	go func() {
		addr := fmt.Sprintf(":%d", *WSPort)
		log.Printf("Starting WebSocket server on %s", addr)
		if err := http.ListenAndServe(addr, nil); err != nil {
			log.Fatal("ListenAndServe: ", err)
		}
	}()

	neuronsdk.LaunchSDK(
		"0.1",    // Specify your app's version
		Protocol, // Specify a protocol ID
		nil,      // leave nil if you don't need custom key configuration logic
		func(ctx context.Context, h host.Host, b *commonlib.NodeBuffers) { // Define buyer case logic here (if required)
			handleP2PMessages(ctx, b, buyerP2PChan)
		},
		func(msg hedera.TopicMessage) { // Define buyer topic callback logic here (if required)
			// Handle buyer topic messages
			buyerP2PChan <- WSMessage{
				Type:      "p2p",
				Data:      string(msg.Contents),
				Timestamp: time.Now().UnixMilli(),
			}
		},
		func(ctx context.Context, h host.Host, b *commonlib.NodeBuffers) { // Define seller case logic here (if required)
			handleP2PMessages(ctx, b, sellerP2PChan)
		},
		func(msg hedera.TopicMessage) {
			// Handle seller topic messages
			sellerP2PChan <- WSMessage{
				Type:      "p2p",
				Data:      string(msg.Contents),
				Timestamp: time.Now().UnixMilli(),
			}
		},
	)
}
