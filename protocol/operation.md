# P256 wallet operation protocol

This demo signs one canonical 32-byte SHA-256 digest. Integer and address fields use Solidity ABI 32-byte slots; addresses are left-padded from 20 to 32 bytes.

```text
TYPEHASH = SHA256(UTF8(
  "P256WalletOperation(address wallet,uint256 chainId,address to,uint256 value,bytes32 dataHash,uint256 nonce,uint256 deadline)"
))

digest = SHA256(ABI_ENCODE(
  TYPEHASH,
  wallet,
  chainId,
  destination,
  valueSun,
  SHA256(calldata),
  nonce,
  deadlineUnixSeconds
))
```

The P-256 signature is transported as two unsigned, big-endian, exactly 32-byte values `r` and `s`. Signers normalize `s` to the lower half of the P-256 group order (`s = min(s, n - s)`) for precompile compatibility. The public key is transported as 32-byte affine coordinates `x` and `y` (the `0x04` X9.63 prefix is not included).

Network APIs may use TRON Base58Check addresses or lowercase `0x`-prefixed 20-byte hex. Base58Check addresses are validated and converted to their 20-byte EVM form before digest construction. The chain ID is read from the deployed wallet through `operationDigest` or from the connected network, never supplied by an untrusted relayer.

This software is an unaudited demonstration and must not hold assets with real value.
