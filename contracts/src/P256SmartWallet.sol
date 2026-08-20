// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {P256Verifier} from "./P256Verifier.sol";

/// @notice Minimal single-key demo wallet. Not audited; do not use for real funds.
contract P256SmartWallet {
    bytes32 public constant OPERATION_TYPEHASH = sha256(
        "P256WalletOperation(address wallet,uint256 chainId,address to,uint256 value,bytes32 dataHash,uint256 nonce,uint256 deadline)"
    );

    bytes32 public immutable publicKeyX;
    bytes32 public immutable publicKeyY;
    uint256 public nonce;

    error InvalidPublicKey();
    error InvalidNonce(uint256 expected, uint256 supplied);
    error OperationExpired(uint256 deadline, uint256 currentTimestamp);
    error InvalidSignature();
    error CallFailed(bytes returnData);

    event Executed(
        bytes32 indexed digest,
        uint256 indexed nonce,
        address indexed destination,
        uint256 value,
        bytes data,
        bytes returnData
    );

    constructor(bytes32 x, bytes32 y) {
        if (x == bytes32(0) || y == bytes32(0)) revert InvalidPublicKey();
        publicKeyX = x;
        publicKeyY = y;
    }

    receive() external payable {}

    function operationDigest(
        address destination,
        uint256 value,
        bytes calldata data,
        uint256 operationNonce,
        uint256 deadline
    ) public view returns (bytes32) {
        return sha256(
            abi.encode(
                OPERATION_TYPEHASH,
                address(this),
                block.chainid,
                destination,
                value,
                sha256(data),
                operationNonce,
                deadline
            )
        );
    }

    function execute(
        address destination,
        uint256 value,
        bytes calldata data,
        uint256 operationNonce,
        uint256 deadline,
        bytes32 r,
        bytes32 s
    ) external returns (bytes memory returnData) {
        if (operationNonce != nonce) revert InvalidNonce(nonce, operationNonce);
        if (block.timestamp > deadline) revert OperationExpired(deadline, block.timestamp);

        bytes32 digest = operationDigest(destination, value, data, operationNonce, deadline);
        if (!P256Verifier.verify(digest, r, s, publicKeyX, publicKeyY)) {
            revert InvalidSignature();
        }

        // Increment before interaction; a revert restores the nonce.
        nonce = operationNonce + 1;
        (bool success, bytes memory result) = destination.call{value: value}(data);
        if (!success) revert CallFailed(result);

        emit Executed(digest, operationNonce, destination, value, data, result);
        return result;
    }
}

