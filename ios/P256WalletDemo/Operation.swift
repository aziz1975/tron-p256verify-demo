import CryptoKit
import Foundation

struct WalletOperation: Codable {
    let wallet: String
    let destination: String
    let valueSun: String
    let data: String
    let nonce: String
    let deadline: String
    let r: String
    let s: String
}

enum OperationEncoder {
    static let chainID: UInt64 = 3_448_148_188
    static let type = "P256WalletOperation(address wallet,uint256 chainId,address to,uint256 value,bytes32 dataHash,uint256 nonce,uint256 deadline)"

    static func sha256(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }

    static func addressWord(_ address: String) throws -> Data {
        let bytes = try Data(hex: address)
        guard bytes.count == 20 else { throw HexError.invalid }
        return try bytes.leftPadded(to: 32)
    }

    static func digest(wallet: String, destination: String, valueSun: UInt64, data: Data, nonce: UInt64, deadline: UInt64) throws -> Data {
        var encoded = Data()
        encoded += sha256(Data(type.utf8))
        encoded += try addressWord(wallet)
        encoded += chainID.abiWord
        encoded += try addressWord(destination)
        encoded += valueSun.abiWord
        encoded += sha256(data)
        encoded += nonce.abiWord
        encoded += deadline.abiWord
        return sha256(encoded)
    }
}

