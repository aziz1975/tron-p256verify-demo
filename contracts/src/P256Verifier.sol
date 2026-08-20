// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @notice Thin wrapper for TIP-7951 / EIP-7951 P-256 verification at 0x100.
library P256Verifier {
    address internal constant PRECOMPILE = address(0x100);

    function verify(bytes32 digest, bytes32 r, bytes32 s, bytes32 x, bytes32 y) internal view returns (bool) {
        (bool success, bytes memory output) = PRECOMPILE.staticcall(abi.encodePacked(digest, r, s, x, y));
        return success && output.length == 32 && abi.decode(output, (uint256)) == 1;
    }
}

