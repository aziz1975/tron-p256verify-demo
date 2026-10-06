// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {P256} from "@openzeppelin/contracts/utils/cryptography/P256.sol";

/// @notice OpenZeppelin-backed TIP-7951 / EIP-7951 verification at 0x100.
library P256Verifier {
    uint256 private constant N = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;

    function verify(bytes32 digest, bytes32 r, bytes32 s, bytes32 x, bytes32 y) internal view returns (bool) {
        // The original precompile accepts both S forms. OpenZeppelin requires low S.
        if (uint256(s) >= N) return false;
        if (uint256(s) > N / 2) s = bytes32(N - uint256(s));

        // Preserve false (rather than MissingPrecompile) on unsupported chains.
        // This fixed valid vector is also used by OpenZeppelin for native detection.
        (bool success, bytes memory output) = address(0x100)
            .staticcall(
                abi.encodePacked(
                    bytes32(0xbb5a52f42f9c9261ed4361f59422a1e30036e7c32b270c8807a419feca605023),
                    bytes32(uint256(5)),
                    bytes32(uint256(1)),
                    bytes32(0xa71af64de5126a4a4e02b7922d66ce9415ce88a4c9d25514d91082c8725ac957),
                    bytes32(0x5d47723c8fbe580bb369fec9c2665d8e30a435b9932645482e7c9f11e872296b)
                )
            );
        if (!success || output.length != 32 || abi.decode(output, (uint256)) != 1) return false;
        return P256.verifyNative(digest, r, s, x, y);
    }
}
