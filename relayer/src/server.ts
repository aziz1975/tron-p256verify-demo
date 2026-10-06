import "dotenv/config";
import express from "express";
import { z } from "zod";
import { operationDigest } from "./protocol.js";
import { verifyDigest } from "./p256.js";
import { createSigningTronWeb, requireBroadcastConfirmation, toTronAddress, tronToEvmAddress } from "./tron.js";
import { walletAbi } from "./wallet-abi.js";

const hex32 = z.string().regex(/^0x[0-9a-fA-F]{64}$/);
const requestSchema = z.object({
  wallet: z.string().min(1), destination: z.string().min(1),
  valueSun: z.string().regex(/^\d+$/), data: z.string().regex(/^0x(?:[0-9a-fA-F]{2})*$/),
  nonce: z.string().regex(/^\d+$/), deadline: z.string().regex(/^\d+$/), r: hex32, s: hex32,
});

const app = express();
app.use(express.json({ limit: "32kb" }));
app.get("/health", (_request, response) => response.json({ ok: true, network: "nile", broadcasting: process.env.CONFIRM_NILE_BROADCAST === "I_UNDERSTAND" }));

function upstreamStatus(error: unknown): number | undefined {
  if (typeof error !== "object" || error === null || !("response" in error)) return undefined;
  const response = (error as { response?: { status?: unknown } }).response;
  return typeof response?.status === "number" ? response.status : undefined;
}

async function readFromNile<T>(label: string, operation: () => Promise<T>): Promise<T> {
  let lastError: unknown;
  for (let attempt = 1; attempt <= 3; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      const status = upstreamStatus(error);
      if (status !== 429 && (status === undefined || status < 500)) break;
      console.warn(`${label} read failed with HTTP ${status}; attempt ${attempt}/3`);
      if (attempt < 3) await new Promise((resolve) => setTimeout(resolve, attempt * 300));
    }
  }
  throw new Error(`${label} read failed: ${lastError instanceof Error ? lastError.message : "Unknown Nile error"}`);
}

app.post("/relay", async (request, response) => {
  try {
    requireBroadcastConfirmation();
    const body = requestSchema.parse(request.body);
    const tronWeb = createSigningTronWeb();
    const walletAddress = toTronAddress(tronWeb, body.wallet);
    const destinationAddress = toTronAddress(tronWeb, body.destination);
    const wallet = await tronWeb.contract(walletAbi as never, walletAddress);
    // Keep these reads sequential: the public Nile endpoint may throttle bursts of
    // simultaneous constant-contract requests.
    const onChainNonce = await readFromNile("nonce", async () => String(await wallet.nonce().call()));
    const x = await readFromNile("publicKeyX", async () => String(await wallet.publicKeyX().call()));
    const y = await readFromNile("publicKeyY", async () => String(await wallet.publicKeyY().call()));
    if (BigInt(onChainNonce) !== BigInt(body.nonce)) {
      throw new Error(
        `Nonce does not match wallet ${walletAddress}: expected ${onChainNonce}, received ${body.nonce}`,
      );
    }
    if (BigInt(body.deadline) <= BigInt(Math.floor(Date.now() / 1000))) throw new Error("Operation has expired");

    const digest = operationDigest({
      wallet: tronToEvmAddress(tronWeb, body.wallet), chainId: 3448148188n,
      destination: tronToEvmAddress(tronWeb, body.destination), valueSun: BigInt(body.valueSun),
      data: body.data, nonce: BigInt(body.nonce), deadline: BigInt(body.deadline),
    });
    if (!verifyDigest(digest, { r: body.r, s: body.s }, x, y)) throw new Error("Invalid P-256 signature");

    const txid = await wallet.execute(destinationAddress, body.valueSun, body.data, body.nonce, body.deadline, body.r, body.s)
      .send({ feeLimit: Number(process.env.FEE_LIMIT_SUN ?? "150000000"), shouldPollResponse: false });
    response.status(202).json({ txid, digest });
  } catch (error) {
    console.error("Relay failed:", error);
    response.status(400).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
});

const port = Number(process.env.RELAYER_PORT ?? "8787");
const host = process.env.RELAYER_HOST ?? "127.0.0.1";
app.listen(port, host, () => console.log(`Nile relayer listening on http://${host}:${port}`));
