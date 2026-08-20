export const walletAbi = [
  { inputs: [], name: "nonce", outputs: [{ type: "uint256" }], stateMutability: "view", type: "function" },
  { inputs: [], name: "publicKeyX", outputs: [{ type: "bytes32" }], stateMutability: "view", type: "function" },
  { inputs: [], name: "publicKeyY", outputs: [{ type: "bytes32" }], stateMutability: "view", type: "function" },
  {
    inputs: [
      { name: "destination", type: "address" }, { name: "value", type: "uint256" },
      { name: "data", type: "bytes" }, { name: "operationNonce", type: "uint256" },
      { name: "deadline", type: "uint256" }, { name: "r", type: "bytes32" }, { name: "s", type: "bytes32" },
    ],
    name: "execute", outputs: [{ type: "bytes" }], stateMutability: "nonpayable", type: "function",
  },
] as const;

