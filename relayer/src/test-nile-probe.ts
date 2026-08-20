import "dotenv/config";
import { createHash, randomBytes } from "node:crypto";
import { readFile } from "node:fs/promises";
import { p256 } from "@noble/curves/p256";
import { hexlify } from "ethers";
import { publicKeyFor, signDigest } from "./p256.js";
import { createReadOnlyTronWeb } from "./tron.js";

const deployedAddress = process.argv[2] ?? process.env.PROBE_CONTRACT_ADDRESS;
if (!deployedAddress) {
  throw new Error(
    "Usage: npm run nile:test:probe -- <probe-address> (or set PROBE_CONTRACT_ADDRESS)",
  );
}

const tronWeb = createReadOnlyTronWeb();
if (!tronWeb.isAddress(deployedAddress)) {
  throw new Error(`Invalid TRON probe address: ${deployedAddress}`);
}
// Nile requires an owner address for triggerconstantcontract even though the
// call is read-only and does not need a private key or broadcast a transaction.
tronWeb.setAddress(deployedAddress);

const artifactPath = new URL(
  "../../out/P256VerifyProbe.sol/P256VerifyProbe.json",
  import.meta.url,
);
const artifact = JSON.parse(await readFile(artifactPath, "utf8")) as {
  abi: unknown[];
};

const probe = await tronWeb.contract(artifact.abi as never, deployedAddress);

// Generate a fresh probe vector on every run. Hashing random input makes the
// digest an explicit 32-byte SHA-256 value rather than a hardcoded test vector.
const privateKey = hexlify(p256.utils.randomPrivateKey());
const digestBytes = createHash("sha256").update(randomBytes(32)).digest();
const digest = hexlify(digestBytes);
const { r, s } = signDigest(digest, privateKey);
const { x, y } = publicKeyFor(privateKey);

// Flip one bit while retaining the signature and public key, so verification
// must fail for the tampered digest.
const tamperedDigestBytes = Uint8Array.from(digestBytes);
tamperedDigestBytes[tamperedDigestBytes.length - 1]! ^= 1;
const tamperedDigest = hexlify(tamperedDigestBytes);

const valid = await probe.verify(digest, r, s, x, y).call();
const tampered = await probe.verify(tamperedDigest, r, s, x, y).call();

console.log(JSON.stringify({ deployedAddress, valid, tampered }, null, 2));

if (valid !== true || tampered !== false) {
  throw new Error(
    `P256VERIFY probe failed: expected valid=true and tampered=false, received valid=${String(valid)} and tampered=${String(tampered)}`,
  );
}

console.log("PASS: Nile executed P256VERIFY correctly.");
