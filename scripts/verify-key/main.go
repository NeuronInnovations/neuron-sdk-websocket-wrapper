package main

import (
	"crypto/ecdsa"
	"encoding/hex"
	"fmt"
	"os"
	"strings"

	ethcrypto "github.com/ethereum/go-ethereum/crypto"
)

// verifyPrivateKey verifies that a private key produces the expected EVM address
// Usage: go run scripts/verify-key/main.go <PRIVATE_KEY_HEX> [EXPECTED_EVM_ADDRESS]
func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go run scripts/verify-key/main.go <PRIVATE_KEY_HEX> [EXPECTED_EVM_ADDRESS]")
		fmt.Println("Example: go run scripts/verify-key/main.go <your-64-char-hex-private-key>")
		fmt.Println("Example: go run scripts/verify-key/main.go <your-64-char-hex-private-key> <expected-evm-address>")
		os.Exit(1)
	}

	privateKeyHex := os.Args[1]
	expectedEVMAddress := ""
	if len(os.Args) >= 3 {
		expectedEVMAddress = strings.ToLower(strings.TrimPrefix(os.Args[2], "0x"))
	}

	if len(privateKeyHex)%2 != 0 {
		fmt.Printf("Error: Private key has odd length (%d hex chars). It should be 64 hex characters (32 bytes).\n", len(privateKeyHex))
		os.Exit(1)
	}

	privateKeyBytes, err := hex.DecodeString(privateKeyHex)
	if err != nil {
		fmt.Printf("Error decoding hex: %v\n", err)
		os.Exit(1)
	}

	fmt.Printf("Private key length: %d bytes (%d hex chars)\n", len(privateKeyBytes), len(privateKeyHex))

	if len(privateKeyBytes) != 32 {
		fmt.Printf("Warning: Private key is not 32 bytes. Adjusting...\n")
		if len(privateKeyBytes) < 32 {
			// Pad with leading zeros
			padded := make([]byte, 32)
			copy(padded[32-len(privateKeyBytes):], privateKeyBytes)
			privateKeyBytes = padded
		} else {
			// Take last 32 bytes
			privateKeyBytes = privateKeyBytes[len(privateKeyBytes)-32:]
		}
		fmt.Printf("Adjusted private key length: %d bytes\n", len(privateKeyBytes))
	}

	privateKey, err := ethcrypto.ToECDSA(privateKeyBytes)
	if err != nil {
		fmt.Printf("Error converting to ECDSA: %v\n", err)
		os.Exit(1)
	}

	publicKey := privateKey.Public()
	publicKeyECDSA, ok := publicKey.(*ecdsa.PublicKey)
	if !ok {
		fmt.Println("Error: Failed to cast public key to ECDSA")
		os.Exit(1)
	}

	evmAddress := ethcrypto.PubkeyToAddress(*publicKeyECDSA)
	evmAddressHex := strings.ToLower(evmAddress.String()[2:]) // Remove 0x prefix and lowercase

	fmt.Printf("\n--- Results ---\n")
	fmt.Printf("EVM Address (without 0x): %s\n", evmAddressHex)
	fmt.Printf("EVM Address (with 0x):    0x%s\n", evmAddressHex)

	if expectedEVMAddress != "" {
		fmt.Printf("\nExpected:                %s\n", expectedEVMAddress)
		if evmAddressHex == expectedEVMAddress {
			fmt.Println("✓✓✓ VERIFICATION PASSED! Private key matches expected EVM address ✓✓✓")
		} else {
			fmt.Println("✗✗✗ VERIFICATION FAILED! Private key does NOT match expected EVM address ✗✗✗")
			os.Exit(1)
		}
	} else {
		fmt.Println("\n✓ Private key is valid and EVM address derived successfully")
	}
}
