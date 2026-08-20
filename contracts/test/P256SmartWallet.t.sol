// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {P256SmartWallet} from "../src/P256SmartWallet.sol";

interface Vm {
    function warp(uint256) external;
    function chainId(uint256) external;
    function deal(address, uint256) external;
    function signP256(uint256 privateKey, bytes32 digest) external returns (bytes32 r, bytes32 s);
}

contract Receiver {
    uint256 public calls;

    receive() external payable {
        calls++;
    }

    function ping() external returns (bytes32) {
        calls++;
        return keccak256("pong");
    }

    function fail() external pure {
        revert("receiver failed");
    }
}

contract P256SmartWalletTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant X = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
    bytes32 private constant Y = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;

    P256SmartWallet private wallet;
    Receiver private receiver;

    function setUp() public {
        vm.chainId(3448148188);
        vm.warp(1_900_000_000);
        wallet = new P256SmartWallet(X, Y);
        receiver = new Receiver();
        vm.deal(address(wallet), 10 ether);
    }

    // Signature generation is covered by cross-language vector tests. This suite
    // verifies digest domains and all rejection paths that precede verification.
    function testDigestChangesWithEveryDomainField() public view {
        bytes memory data = hex"12345678";
        bytes32 original = wallet.operationDigest(address(receiver), 1_234_567, data, 0, 2_000_000_000);
        require(original != wallet.operationDigest(address(0x1234), 1_234_567, data, 0, 2_000_000_000));
        require(original != wallet.operationDigest(address(receiver), 1_234_568, data, 0, 2_000_000_000));
        require(original != wallet.operationDigest(address(receiver), 1_234_567, hex"12345679", 0, 2_000_000_000));
        require(original != wallet.operationDigest(address(receiver), 1_234_567, data, 1, 2_000_000_000));
        require(original != wallet.operationDigest(address(receiver), 1_234_567, data, 0, 2_000_000_001));
    }

    function testRejectsWrongNonceBeforeSignatureCheck() public {
        (bool ok, bytes memory reason) = address(wallet)
            .call(
                abi.encodeCall(
                    wallet.execute, (address(receiver), 0, bytes(""), 1, 2_000_000_000, bytes32(0), bytes32(0))
                )
            );
        require(!ok && bytes4(reason) == P256SmartWallet.InvalidNonce.selector);
    }

    function testRejectsExpiredBeforeSignatureCheck() public {
        (bool ok, bytes memory reason) = address(wallet)
            .call(
                abi.encodeCall(
                    wallet.execute, (address(receiver), 0, bytes(""), 0, 1_899_999_999, bytes32(0), bytes32(0))
                )
            );
        require(!ok && bytes4(reason) == P256SmartWallet.OperationExpired.selector);
    }

    function testRejectsInvalidSignature() public {
        (bool ok, bytes memory reason) = address(wallet)
            .call(
                abi.encodeCall(
                    wallet.execute, (address(receiver), 0, bytes(""), 0, 2_000_000_000, bytes32(0), bytes32(0))
                )
            );
        require(!ok && bytes4(reason) == P256SmartWallet.InvalidSignature.selector);
        require(wallet.nonce() == 0);
    }

    function testValidExecutionAndReplayProtection() public {
        bytes memory data = abi.encodeCall(receiver.ping, ());
        uint256 deadline = 2_000_000_000;
        bytes32 digest = wallet.operationDigest(address(receiver), 0, data, 0, deadline);
        (bytes32 r, bytes32 s) = vm.signP256(1, digest);

        bytes memory result = wallet.execute(address(receiver), 0, data, 0, deadline, r, s);
        require(abi.decode(result, (bytes32)) == keccak256("pong"));
        require(wallet.nonce() == 1 && receiver.calls() == 1);

        (bool replayOk, bytes memory reason) =
            address(wallet).call(abi.encodeCall(wallet.execute, (address(receiver), 0, data, 0, deadline, r, s)));
        require(!replayOk && bytes4(reason) == P256SmartWallet.InvalidNonce.selector);
    }
}
