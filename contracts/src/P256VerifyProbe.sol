// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {P256Verifier} from "./P256Verifier.sol";

contract P256VerifyProbe {
    function verify(bytes32 digest, bytes32 r, bytes32 s, bytes32 x, bytes32 y) external view returns (bool) {
        return P256Verifier.verify(digest, r, s, x, y);
    }
}

