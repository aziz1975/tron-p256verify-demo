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

app.post("/relay", async (request, response) => {
  try {
    requireBroadcastConfirmation();
    const body = requestSchema.parse(request.body);
    const tronWeb = createSigningTronWeb();
    const walletAddress = toTronAddress(tronWeb, body.wallet);
    const destinationAddress = toTronAddress(tronWeb, body.destination);
    const wallet = await tronWeb.contract(walletAbi as never, walletAddress);
    const [onChainNonce, x, y] = await Promise.all([wallet.nonce().call(), wallet.publicKeyX().call(), wallet.publicKeyY().call()]);
    if (BigInt(onChainNonce.toString()) !== BigInt(body.nonce)) throw new Error("Nonce does not match wallet");
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
    response.status(400).json({ error: error instanceof Error ? error.message : "Unknown error" });
  }
});

const port = Number(process.env.RELAYER_PORT ?? "8787");
const host = process.env.RELAYER_HOST ?? "127.0.0.1";
app.listen(port, host, () => console.log(`Nile relayer listening on http://${host}:${port}`));
