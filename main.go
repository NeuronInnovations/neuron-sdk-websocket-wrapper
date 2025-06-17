package main

import (
	"bufio"
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"time"

	neuronsdk "github.com/NeuronInnovations/neuron-go-hedera-sdk" // Import neuronFactory from neuron-go-sdk
	commonlib "github.com/NeuronInnovations/neuron-go-hedera-sdk/common-lib"
	hedera_msg "github.com/NeuronInnovations/neuron-go-hedera-sdk/hedera"
	"github.com/NeuronInnovations/neuron-go-hedera-sdk/keylib"
	"github.com/NeuronInnovations/neuron-go-hedera-sdk/types"
	"github.com/gorilla/websocket"
	"github.com/hashgraph/hedera-sdk-go/v2"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/protocol"
	"github.com/spf13/pflag"
)

var (
	Protocol = protocol.ID(*pflag.String("protocol", "nrn-nodered/v1", "Protocol ID for the neuron network"))
	WSPort   = pflag.Int("ws-port", 8080, "WebSocket server port")
)

func init() {
	// Set up custom logger with file and line information
	log.SetFlags(0) // Remove default flags
	log.SetOutput(&locationWriter{os.Stdout})
}

// locationWriter is a custom writer that adds file and line information to log messages
type locationWriter struct {
	*os.File
}

func (w *locationWriter) Write(p []byte) (n int, err error) {
	_, file, line, _ := runtime.Caller(3) // Skip the log package's internal calls
	file = filepath.Base(file)            // Get just the filename without the path
	prefix := fmt.Sprintf("[%s:%d] ", file, line)
	return w.File.Write(append([]byte(prefix), p...))
}

// WebSocket message structure
type WSMessage struct {
	Type      string      `json:"type"`
	Data      interface{} `json:"data"`
	Timestamp int64       `json:"timestamp"`
	PublicKey string      `json:"publicKey,omitempty"` // Optional field to specify target peer
	Error     string      `json:"error,omitempty"`     // Add error field for responses
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
func handleWebSocket(w http.ResponseWriter, r *http.Request, wsToP2P chan WSMessage, p2pToWS chan WSMessage) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("Failed to upgrade connection: %v", err)
		return
	}
	defer conn.Close()

	// Create a done channel to signal when the connection is closed
	done := make(chan struct{})

	// Handle incoming messages
	go func() {
		defer close(done)
		for {
			var msg WSMessage
			err := conn.ReadJSON(&msg)
			if err != nil {
				log.Printf("Error reading message: %v", err)
				return
			}
			wsToP2P <- msg
		}
	}()

	// Send messages to client
	for {
		select {
		case <-done:
			return
		case msg := <-p2pToWS:
			err := conn.WriteJSON(msg)
			if err != nil {
				log.Printf("Error writing message: %v", err)
				return
			}
		}
	}
}

// handleStream processes incoming messages from a P2P stream
func handleStream(stream network.Stream, b *commonlib.NodeBuffers, p2pToWS chan WSMessage) {
	defer stream.Close()
	peerID := stream.Conn().RemotePeer()
	streamReader := bufio.NewReader(stream)

	log.Printf("Stream established with peer %s and stream id %s\n", peerID, stream.ID())

	for {
		isStreamClosed := network.Stream.Conn(stream).IsClosed()
		if isStreamClosed {
			log.Printf("Stream seems to be closed ...", peerID)
			b.RemoveBuffer(peerID) // Clean up the buffer when stream is closed
			break
		}

		// Set a read deadline to avoid blocking indefinitely
		stream.SetReadDeadline(time.Now().Add(5 * time.Second))

		// Read data without requiring newline
		buffer := make([]byte, 1024)
		n, err := streamReader.Read(buffer)

		// Check for timeout
		if err != nil {
			if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
				// This is a timeout, which is expected
				log.Printf("No data received from %s in 5 seconds, continuing...\n", peerID)
				continue
			}

			// For other errors, log them
			log.Printf("Error reading from stream: %v\n", err)
			continue
		}

		if n > 0 {
			// Forward the message to WebSocket
			log.Printf("Received from %s: %s\n", peerID, string(buffer[:n]))
			p2pToWS <- WSMessage{
				Type:      "p2p",
				Data:      string(buffer[:n]),
				Timestamp: time.Now().UnixMilli(),
			}
		}
	}
}

// Handle P2P messages from WebSocket and forward to peers. By default, the seller uses newStream and the buyer catches the event using setstreamhandler.
// If we want the buyer to send a message to the seller then the buyer can either create newStream so that the seller's streamhandler fires or, ad it is done here,
// we can "find" the stream and send the message to the seller.
func handleP2PMessages(ctx context.Context, h host.Host, b *commonlib.NodeBuffers, wsToP2P chan WSMessage, p2pToWS chan WSMessage, isBuyer bool) {
	if isBuyer { // listens for  newstream
		// Set up stream handler for incoming P2P messages (Buyer case)
		log.Printf("Setting up stream handler for protocol %s", Protocol)
		h.SetStreamHandler(Protocol, func(stream network.Stream) {
			handleStream(stream, b, p2pToWS)
		})
	} else { // is seller finds existing stream and handles it
		// Seller case - start a goroutine to handle incoming messages
		go func() {
			for {
				select {
				case <-ctx.Done():
					return
				default:
					// Check for any active streams and handle them
					for _, conn := range h.Network().Conns() {
						streams := conn.GetStreams()
						for _, stream := range streams {
							if stream.Protocol() == Protocol {
								handleStream(stream, b, p2pToWS)
							}
						}
					}
				}
			}
		}()
	}

	// Handle outgoing messages to peers
	go func() {
		for {
			select {
			case <-ctx.Done():
				return
			case msg := <-wsToP2P:
				// Convert message to bytes
				msgBytes := []byte(msg.Data.(string) + "\n")

				// Get the target public key from the message
				targetPublicKey := msg.PublicKey
				if targetPublicKey == "" {
					errorMsg := WSMessage{
						Type:      "error",
						Data:      "No target public key specified in message",
						Timestamp: time.Now().UnixMilli(),
						Error:     "MISSING_PUBLIC_KEY",
					}
					p2pToWS <- errorMsg
					continue
				}

				// Log the received public key for debugging
				log.Printf("Received public key: %s (length: %d)", targetPublicKey, len(targetPublicKey))

				// Find the peer with matching public key
				targetPeerIDStr, err := keylib.ConvertHederaPublicKeyToPeerID(targetPublicKey)
				if err != nil {
					errorMsg := WSMessage{
						Type:      "error",
						Data:      fmt.Sprintf("Error converting public key: %v", err),
						Timestamp: time.Now().UnixMilli(),
						Error:     "INVALID_PUBLIC_KEY",
					}
					p2pToWS <- errorMsg
					continue
				}
				log.Printf("Converted public key %s to peer ID string: %s", targetPublicKey, targetPeerIDStr)

				targetPeerID, err := peer.Decode(targetPeerIDStr)
				if err != nil {
					errorMsg := WSMessage{
						Type:      "error",
						Data:      fmt.Sprintf("Error decoding peer ID: %v", err),
						Timestamp: time.Now().UnixMilli(),
						Error:     "PEER_ID_DECODE_ERROR",
					}
					p2pToWS <- errorMsg
					continue
				}
				log.Printf("Decoded peer ID: %s", targetPeerID.String())

				// Debug: Print all available peer IDs in the buffer map
				log.Printf("Available peer IDs in buffer map:")
				for existingPeerID := range b.GetBufferMap() {
					log.Printf("  - %s", existingPeerID.String())
				}

				// Get buffer info for the target peer
				bufferInfo, exists := b.GetBuffer(targetPeerID)
				if !exists {
					errorMsg := WSMessage{
						Type:      "error",
						Data:      fmt.Sprintf("No buffer found for peer %s", targetPublicKey),
						Timestamp: time.Now().UnixMilli(),
						Error:     "PEER_NOT_FOUND",
					}
					p2pToWS <- errorMsg
					continue
				}

				// Send the message to the specific peer
				log.Printf("Sending message to peer %s", targetPublicKey)
				sendError := commonlib.WriteAndFlushBuffer(*bufferInfo, targetPeerID, b, msgBytes, h, Protocol)
				if sendError != nil {
					// Send the public connectivity error message for the other peer's sdk to handle
					hedera_msg.PeerSendErrorMessage(
						bufferInfo.RequestOrResponse.OtherStdInTopic,
						types.WriteError,
						"Failed to send message: "+sendError.Error()+string(msgBytes),
						types.SendFreshHederaRequest,
					)
					errorMsg := WSMessage{
						Type:      "error",
						Data:      fmt.Sprintf("Error sending to peer %s: %v", targetPublicKey, sendError),
						Timestamp: time.Now().UnixMilli(),
						Error:     "SEND_ERROR",
					}
					p2pToWS <- errorMsg
					continue
				}

				// Send success response
				successMsg := WSMessage{
					Type:      "success",
					Data:      fmt.Sprintf("Successfully sent message to peer %s", targetPublicKey),
					Timestamp: time.Now().UnixMilli(),
				}
				p2pToWS <- successMsg
			}
		}
	}()
}

func main() {
	// Parse command line flags
	pflag.Parse()

	// Create separate channels for WebSocket to P2P and P2P to WebSocket
	buyerWSToP2P := make(chan WSMessage)
	buyerP2PToWS := make(chan WSMessage)
	sellerWSToP2P := make(chan WSMessage)
	sellerP2PToWS := make(chan WSMessage)

	// Set up HTTP routes for P2P
	http.HandleFunc("/buyer/p2p", func(w http.ResponseWriter, r *http.Request) {
		handleWebSocket(w, r, buyerWSToP2P, buyerP2PToWS)
	})
	http.HandleFunc("/seller/p2p", func(w http.ResponseWriter, r *http.Request) {
		handleWebSocket(w, r, sellerWSToP2P, sellerP2PToWS)
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
		func(ctx context.Context, h host.Host, b *commonlib.NodeBuffers) { // Define buyer case logic here
			handleP2PMessages(ctx, h, b, buyerWSToP2P, buyerP2PToWS, true)
		},
		func(msg hedera.TopicMessage) { // Define buyer topic callback logic here
			// Handle buyer topic messages
			buyerP2PToWS <- WSMessage{
				Type:      "p2p",
				Data:      string(msg.Contents),
				Timestamp: time.Now().UnixMilli(),
			}
		},
		func(ctx context.Context, h host.Host, b *commonlib.NodeBuffers) { // Define seller case logic here
			handleP2PMessages(ctx, h, b, sellerWSToP2P, sellerP2PToWS, false)
		},
		func(msg hedera.TopicMessage) {
			// Handle seller topic messages
			sellerP2PToWS <- WSMessage{
				Type:      "p2p",
				Data:      string(msg.Contents),
				Timestamp: time.Now().UnixMilli(),
			}
		},
	)
}
