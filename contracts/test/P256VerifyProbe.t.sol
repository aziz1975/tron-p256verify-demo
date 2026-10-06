// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {P256VerifyProbe} from "../src/P256VerifyProbe.sol";

interface ProbeVm {
    function mockCall(address, bytes calldata, bytes calldata) external;
    function signP256(uint256, bytes32) external returns (bytes32, bytes32);
}

contract P256VerifyProbeTest {
    ProbeVm private constant vm = ProbeVm(address(uint160(uint256(keccak256("hevm cheat code")))));
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

    function testHighSAcceptedLikeOriginalVerifier() public view {
        bytes32 highS = bytes32(0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551 - uint256(S));
        require(probe.verify(DIGEST, R, highS, X, Y), "high S rejected");
        require(!probe.verify(bytes32(uint256(DIGEST) ^ 1), R, highS, X, Y), "tampered high S accepted");
    }

    function testFuzzMatchesOriginalVerifier(bytes32 digest, bytes32 r, bytes32 s, bytes32 x, bytes32 y) public view {
        (bool success, bytes memory output) = address(0x100).staticcall(abi.encodePacked(digest, r, s, x, y));
        bool original = success && output.length == 32 && abi.decode(output, (uint256)) == 1;
        require(probe.verify(digest, r, s, x, y) == original, "verification behavior changed");
    }

    function testRejectsScalarBoundaries() public view {
        bytes32 n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
        require(!probe.verify(DIGEST, 0, S, X, Y));
        require(!probe.verify(DIGEST, n, S, X, Y));
        require(!probe.verify(DIGEST, R, 0, X, Y));
        require(!probe.verify(DIGEST, R, n, X, Y));
        require(!probe.verify(DIGEST, R, bytes32(type(uint256).max), X, Y));
    }

    function testMissingPrecompileReturnsFalse() public {
        vm.mockCall(address(0x100), bytes(""), bytes(""));
        require(!probe.verify(DIGEST, R, S, X, Y), "missing precompile accepted");
    }

    function testFuzzValidSignaturesBothSForms(bytes32 digest) public {
        (bytes32 r, bytes32 s) = vm.signP256(1, digest);
        bytes32 flippedS = bytes32(0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551 - uint256(s));
        require(probe.verify(digest, r, s, X, Y), "valid signature rejected");
        require(probe.verify(digest, r, flippedS, X, Y), "flipped signature rejected");
    }
}
