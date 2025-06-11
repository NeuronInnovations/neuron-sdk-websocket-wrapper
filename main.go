package main

import (
	"context"

	neuronsdk "github.com/NeuronInnovations/neuron-go-hedera-sdk" // Import neuronFactory from neuron-go-sdk
	commonlib "github.com/NeuronInnovations/neuron-go-hedera-sdk/common-lib"
	"github.com/hashgraph/hedera-sdk-go/v2"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/protocol"
	"github.com/spf13/pflag"
)

var Protocol = protocol.ID(*pflag.String("protocol", "nrn-nodered/v1", "Protocol ID for the neuron network"))

func main() {
	// Parse command line flags
	pflag.Parse()

	neuronsdk.LaunchSDK(
		"0.1",    // Specify your app's version =
		Protocol, // Specify a protocol ID = nrn-mpc/v1
		nil,      // leave nil if you don't need custom key configuration logic
		func(ctx context.Context, h host.Host, b *commonlib.NodeBuffers) { // Define buyer case logic here (if required)
			// Set up the proxy for the buyer case
		},
		func(msg hedera.TopicMessage) { // Define buyer topic callback logic here (if required)
			// Define seller topic callback logic here (if required)
		},
		func(ctx context.Context, h host.Host, b *commonlib.NodeBuffers) { // Define seller case logic here (if required)
			// Set up the proxy for the seller case
		},
		func(msg hedera.TopicMessage) {
			// Define seller topic callback logic here (if required)
		},
	)
}
