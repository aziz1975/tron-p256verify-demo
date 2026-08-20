import "dotenv/config";
import { createReadOnlyTronWeb, NILE_FULL_HOST } from "./tron.js";

const tronWeb = createReadOnlyTronWeb();
const parameters = await tronWeb.fullNode.request("wallet/getchainparameters", {}, "post") as { chainParameter?: Array<{ key: string; value?: number }> };
const osaka = parameters.chainParameter?.find((entry) => entry.key === "getAllowTvmOsaka")?.value;
console.log(JSON.stringify({ endpoint: NILE_FULL_HOST, allowTvmOsaka: osaka, p256verifyActive: osaka === 1 }, null, 2));
if (osaka !== 1) process.exitCode = 1;

