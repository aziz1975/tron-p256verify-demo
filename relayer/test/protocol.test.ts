import assert from "node:assert/strict";
import test from "node:test";
import { operationDigest, OPERATION_TYPEHASH } from "../src/protocol.js";
import { publicKeyFor, signDigest, verifyDigest } from "../src/p256.js";

const vector = {
  wallet: "0x1111111111111111111111111111111111111111",
  chainId: 3448148188n,
  destination: "0x2222222222222222222222222222222222222222",
  valueSun: 1234567n,
  data: "0x12345678",
  nonce: 0n,
  deadline: 2000000000n,
};

test("typehash and operation digest match the shared vector", () => {
  assert.equal(OPERATION_TYPEHASH, "0x801738df24c1c2867484d41f97805ff307f593c528e48eb396c11edea33af945");
  assert.equal(operationDigest(vector), "0x85e1b4fdda9d036e24f5fa6192858c398c59b7c2fa79ada2b3abafec747416d0");
});

test("signs a digest without double hashing and rejects tampering", () => {
  const privateKey = `0x${"0".repeat(63)}1`;
  const key = publicKeyFor(privateKey);
  const digest = operationDigest(vector);
  const signature = signDigest(digest, privateKey);
  assert.equal(key.x, "0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296");
  assert.equal(key.y, "0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5");
  assert.ok(verifyDigest(digest, signature, key.x, key.y));
  assert.ok(!verifyDigest(`0x${"00".repeat(32)}`, signature, key.x, key.y));
});

test("every operation domain field changes the digest", () => {
  const original = operationDigest(vector);
  assert.notEqual(operationDigest({ ...vector, wallet: "0x3333333333333333333333333333333333333333" }), original);
  assert.notEqual(operationDigest({ ...vector, chainId: vector.chainId + 1n }), original);
  assert.notEqual(operationDigest({ ...vector, destination: "0x3333333333333333333333333333333333333333" }), original);
  assert.notEqual(operationDigest({ ...vector, valueSun: vector.valueSun + 1n }), original);
  assert.notEqual(operationDigest({ ...vector, data: "0x12345679" }), original);
  assert.notEqual(operationDigest({ ...vector, nonce: 1n }), original);
  assert.notEqual(operationDigest({ ...vector, deadline: vector.deadline + 1n }), original);
});

