import { TronWeb } from "tronweb";

export const NILE_FULL_HOST = process.env.NILE_FULL_HOST ?? "https://nile.trongrid.io";

export function createReadOnlyTronWeb(): TronWeb {
  return new TronWeb({ fullHost: NILE_FULL_HOST });
}

export function createSigningTronWeb(): TronWeb {
  const privateKey = process.env.NILE_PRIVATE_KEY;
  if (!privateKey) throw new Error("NILE_PRIVATE_KEY is required (use a Nile-only test key)");
  return new TronWeb({ fullHost: NILE_FULL_HOST, privateKey });
}

export function tronToEvmAddress(tronWeb: TronWeb, address: string): string {
  if (/^0x[0-9a-fA-F]{40}$/.test(address)) return address;
  const hex = tronWeb.address.toHex(address).replace(/^0x/, "");
  if (!/^41[0-9a-fA-F]{40}$/.test(hex)) throw new Error("Invalid TRON address");
  return `0x${hex.slice(2)}`;
}

export function toTronAddress(tronWeb: TronWeb, address: string): string {
  if (/^0x[0-9a-fA-F]{40}$/.test(address)) return tronWeb.address.fromHex(`41${address.slice(2)}`);
  if (!tronWeb.isAddress(address)) throw new Error("Invalid TRON address");
  return address;
}

export function requireBroadcastConfirmation(): void {
  if (process.env.CONFIRM_NILE_BROADCAST !== "I_UNDERSTAND") {
    throw new Error("Broadcast disabled. Set CONFIRM_NILE_BROADCAST=I_UNDERSTAND only after explicit approval.");
  }
}
