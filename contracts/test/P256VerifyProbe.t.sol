// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {P256VerifyProbe} from "../src/P256VerifyProbe.sol";

contract P256VerifyProbeTest {
    P256VerifyProbe private probe;

    bytes32 private constant DIGEST = 0x85e1b4fdda9d036e24f5fa6192858c398c59b7c2fa79ada2b3abafec747416d0;
    bytes32 private constant R = 0x609a9a49d10d0c502d6602aa1f75c04ab6b0759056d13f1dafe66e496519dce5;
    bytes32 private constant S = 0x06230f6a5de36fcfddd8ee5018f31055d1c611ec57afeb216170b1992d67c8a4;
    bytes32 private constant X = 0x6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296;
    bytes32 private constant Y = 0x4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5;

    function setUp() public {
        probe = new P256VerifyProbe();
    }

    function testValidVector() public view {
        require(probe.verify(DIGEST, R, S, X, Y), "valid vector rejected");
    }

    function testTamperedDigest() public view {
        require(!probe.verify(bytes32(uint256(DIGEST) ^ 1), R, S, X, Y), "tampered vector accepted");
    }

    function testWrongKey() public view {
        require(!probe.verify(DIGEST, R, S, X, bytes32(uint256(Y) ^ 1)), "wrong key accepted");
    }
}
