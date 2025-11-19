package main

import (
	"crypto/ecdsa"
	"encoding/asn1"
	"encoding/hex"
	"fmt"
	"log"
	"os"
	"strings"

	ethcrypto "github.com/ethereum/go-ethereum/crypto"
)

type ecPrivateKey struct {
	Version       int
	PrivateKey    []byte
	NamedCurveOID asn1.ObjectIdentifier `asn1:"optional,explicit,tag:0"`
	PublicKey     asn1.BitString        `asn1:"optional,explicit,tag:1"`
}

// extractKeyFromDER extracts a private key from DER format and derives the EVM address
// Usage: go run scripts/extract-key/main.go <DER_HEX_STRING>
func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run scripts/extract-key/main.go <DER_HEX_STRING>")
		fmt.Println("Example: go run scripts/extract-key/main.go 30540201010420<your-der-hex-string>...")
		os.Exit(1)
	}

	// DER-encoded private key from command line
	derHex := os.Args[1]

	derBytes, err := hex.DecodeString(derHex)
	if err != nil {
		log.Fatalf("Failed to decode DER hex: %v", err)
	}

	// Parse DER using ASN.1
	var ecPrivKey ecPrivateKey
	_, err = asn1.Unmarshal(derBytes, &ecPrivKey)
	if err != nil {
		log.Fatalf("Failed to parse DER: %v", err)
	}

	privateKeyBytes := ecPrivKey.PrivateKey

	// Ensure private key is exactly 32 bytes (pad with leading zero if needed)
	if len(privateKeyBytes) < 32 {
		// Pad with leading zeros
		padded := make([]byte, 32)
		copy(padded[32-len(privateKeyBytes):], privateKeyBytes)
		privateKeyBytes = padded
	} else if len(privateKeyBytes) > 32 {
		// Take last 32 bytes
		privateKeyBytes = privateKeyBytes[len(privateKeyBytes)-32:]
	}

	privateKeyHex := hex.EncodeToString(privateKeyBytes)

	fmt.Printf("Private Key (hex, length %d): %s\n", len(privateKeyHex), privateKeyHex)
	fmt.Printf("Private Key (bytes, length %d): %x\n", len(privateKeyBytes), privateKeyBytes)

	// Convert to ECDSA private key
	privateKey, err := ethcrypto.ToECDSA(privateKeyBytes)
	if err != nil {
		log.Fatalf("Failed to convert to ECDSA key: %v", err)
	}

	// Derive public key and then EVM address
	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		log.Fatal("Failed to cast public key to ECDSA")
	}

	// Get EVM address (Ethereum address)
	evmAddress := ethcrypto.PubkeyToAddress(*publicKeyECDSA)
	evmAddressHex := strings.ToLower(evmAddress.String()[2:]) // Remove 0x prefix and lowercase

	fmt.Printf("EVM Address (without 0x): %s\n", evmAddressHex)
	fmt.Printf("\n--- Environment File Values ---\n")
	fmt.Printf("private_key=%s\n", privateKeyHex)
	fmt.Printf("hedera_evm_id=%s\n", evmAddressHex)
}
