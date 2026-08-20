import { p256 } from "@noble/curves/p256";
import { getBytes, hexlify } from "ethers";
import { fixed32 } from "./protocol.js";

export type RawSignature = { r: string; s: string };

export function signDigest(digest: string, privateKey: string): RawSignature {
  const signature = p256.sign(getBytes(digest), getBytes(privateKey), { prehash: false, lowS: true });
  return { r: fixed32(signature.r.toString(16).padStart(64, "0")), s: fixed32(signature.s.toString(16).padStart(64, "0")) };
}

export function verifyDigest(digest: string, signature: RawSignature, x: string, y: string): boolean {
  const compact = new Uint8Array([...getBytes(signature.r), ...getBytes(signature.s)]);
  const publicKey = new Uint8Array([4, ...getBytes(x), ...getBytes(y)]);
  return p256.verify(compact, getBytes(digest), publicKey, { prehash: false, lowS: true });
}

export function publicKeyFor(privateKey: string): { x: string; y: string; x963: string } {
  const x963 = p256.getPublicKey(getBytes(privateKey), false);
  return {
    x: hexlify(x963.slice(1, 33)),
    y: hexlify(x963.slice(33, 65)),
    x963: hexlify(x963),
  };
}

