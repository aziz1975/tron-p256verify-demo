import "dotenv/config";
import { readFile } from "node:fs/promises";
import { createSigningTronWeb, requireBroadcastConfirmation } from "./tron.js";

requireBroadcastConfirmation();
const target = process.argv[2];
if (target !== "probe" && target !== "wallet") throw new Error("Usage: deploy.ts probe|wallet");
const contractName = target === "probe" ? "P256VerifyProbe" : "P256SmartWallet";
const artifactPath = new URL(`../../out/${contractName}.sol/${contractName}.json`, import.meta.url);
const artifact = JSON.parse(await readFile(artifactPath, "utf8")) as { abi: unknown[]; bytecode: { object: string } };
const parameters = target === "wallet" ? [process.env.P256_PUBLIC_KEY_X, process.env.P256_PUBLIC_KEY_Y] : [];
if (target === "wallet" && parameters.some((value) => !/^0x[0-9a-fA-F]{64}$/.test(value ?? ""))) {
  throw new Error("P256_PUBLIC_KEY_X and P256_PUBLIC_KEY_Y must be bytes32 hex");
}
const tronWeb = createSigningTronWeb();
const contract = await tronWeb.contract().new({
  abi: artifact.abi as never, bytecode: artifact.bytecode.object,
  feeLimit: Number(process.env.FEE_LIMIT_SUN ?? "150000000"), parameters,
});
console.log(`${contractName} deployed at ${contract.address}`);

