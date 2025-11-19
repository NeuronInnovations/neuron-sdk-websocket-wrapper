# Key Management Tools

This directory contains utility scripts for extracting and verifying private keys from DER format.

## Scripts

### 1. `extract-key-from-der.go`

Extracts a private key from DER format and derives the corresponding EVM address.

**Usage:**
```bash
go run scripts/extract-key/main.go <DER_HEX_STRING>
```

**Example:**
```bash
go run scripts/extract-key/main.go <your-der-hex-string>
```

**Output:**
- Private key in hex format (64 characters)
- EVM address (without 0x prefix)
- Environment file format values for `private_key` and `hedera_evm_id`

**Use Case:**
When you have a private key in DER format and need to:
- Convert it to hex format for environment files
- Derive the EVM address for the `hedera_evm_id` field

---

### 2. `verify-private-key.go`

Verifies that a private key produces the expected EVM address.

**Usage:**
```bash
go run scripts/verify-key/main.go <PRIVATE_KEY_HEX> [EXPECTED_EVM_ADDRESS]
```

**Examples:**
```bash
# Just verify the key is valid and show the EVM address
go run scripts/verify-key/main.go <your-64-char-hex-private-key>

# Verify the key matches an expected EVM address
go run scripts/verify-key/main.go <your-64-char-hex-private-key> <expected-evm-address>
```

**Output:**
- Private key validation status
- Derived EVM address
- Verification result (if expected address provided)

**Use Case:**
- Verify a private key is correctly formatted
- Confirm a private key matches a known EVM address
- Debug key/address mismatches

---

## Workflow Example

### Creating a new seller environment file

1. **Extract key from DER:**
   ```bash
   go run scripts/extract-key/main.go <DER_HEX_STRING>
   ```

2. **Copy the output values:**
   - `private_key=...`
   - `hedera_evm_id=...`

3. **Verify the key (optional but recommended):**
   ```bash
   go run scripts/verify-key/main.go <PRIVATE_KEY_HEX> <EVM_ADDRESS>
   ```

4. **Create the environment file:**
   ```bash
   cat > .seller-env-new << EOF
   eth_rpc_url=https://testnet.hashio.io/api
   hedera_evm_id=<EVM_ADDRESS_FROM_STEP_2>
   hedera_id=0.0.XXXXXXX
   location={"lat":3.1574851,"lon":101.7108034,"alt":0.000000}
   mirror_api_url=https://testnet.mirrornode.hedera.com/api/v1
   private_key=<PRIVATE_KEY_FROM_STEP_2>
   smart_contract_address=0xFcBC43d2207580F82c07aE2E09e9d0cA0211B048
   EOF
   ```

---

## Notes

- Private keys must be exactly 32 bytes (64 hex characters)
- EVM addresses are derived from the public key using Keccak-256
- All addresses are output without the `0x` prefix to match Hedera environment file format
- The scripts handle padding/truncation automatically if needed

