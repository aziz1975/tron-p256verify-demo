import { AbiCoder, concat, getAddress, getBytes, hexlify, sha256, toUtf8Bytes, zeroPadValue } from "ethers";

export const OPERATION_TYPE =
  "P256WalletOperation(address wallet,uint256 chainId,address to,uint256 value,bytes32 dataHash,uint256 nonce,uint256 deadline)";
export const OPERATION_TYPEHASH = sha256(toUtf8Bytes(OPERATION_TYPE));

export type WalletOperation = {
  wallet: string;
  chainId: bigint;
  destination: string;
  valueSun: bigint;
  data: string;
  nonce: bigint;
  deadline: bigint;
};

export function normalizeEvmAddress(value: string): string {
  const raw = value.startsWith("0x") ? value : `0x${value}`;
  if (!/^0x[0-9a-fA-F]{40}$/.test(raw)) throw new Error("Expected a 20-byte hex address");
  return getAddress(raw);
}

export function operationDigest(operation: WalletOperation): string {
  const coder = AbiCoder.defaultAbiCoder();
  const encoded = coder.encode(
    ["bytes32", "address", "uint256", "address", "uint256", "bytes32", "uint256", "uint256"],
    [
      OPERATION_TYPEHASH,
      normalizeEvmAddress(operation.wallet),
      operation.chainId,
      normalizeEvmAddress(operation.destination),
      operation.valueSun,
      sha256(operation.data),
      operation.nonce,
      operation.deadline,
    ],
  );
  return sha256(encoded);
}

export function splitX963PublicKey(publicKey: string): { x: string; y: string } {
  const bytes = getBytes(publicKey);
  if (bytes.length !== 65 || bytes[0] !== 4) throw new Error("Expected uncompressed 65-byte X9.63 key");
  return { x: hexlify(bytes.slice(1, 33)), y: hexlify(bytes.slice(33, 65)) };
}

export function fixed32(value: Uint8Array | string): string {
  const normalized = typeof value === "string" && !value.startsWith("0x") ? `0x${value}` : value;
  return hexlify(zeroPadValue(hexlify(normalized), 32));
}

export function joinSignature(r: string, s: string): string {
  return hexlify(concat([fixed32(r), fixed32(s)]));
}
