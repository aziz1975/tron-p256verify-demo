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

enum TronAddressError: LocalizedError {
    case invalidBase58, invalidLength, invalidPrefix, invalidChecksum

    var errorDescription: String? {
        switch self {
        case .invalidBase58: "Address is not valid Base58"
        case .invalidLength: "TRON address must decode to 25 bytes"
        case .invalidPrefix: "Address is not a TRON mainnet or Nile address"
        case .invalidChecksum: "TRON address checksum is invalid"
        }
    }
}

enum TronAddress {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".utf8)
    private static let values = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, $0) })

    static func normalized(_ address: String) throws -> String {
        let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try evmBytes(value)
        return value
    }

    static func evmBytes(_ address: String) throws -> Data {
        let characters = Array(address.utf8)
        guard !characters.isEmpty else { throw TronAddressError.invalidBase58 }

        let leadingZeroCount = characters.prefix { $0 == alphabet[0] }.count
        var decoded: [UInt8] = []
        for character in characters.dropFirst(leadingZeroCount) {
            guard let digit = values[character] else { throw TronAddressError.invalidBase58 }
            var carry = digit
            for index in decoded.indices.reversed() {
                let value = Int(decoded[index]) * 58 + carry
                decoded[index] = UInt8(value & 0xff)
                carry = value >> 8
            }
            while carry > 0 {
                decoded.insert(UInt8(carry & 0xff), at: 0)
                carry >>= 8
            }
        }

        let raw = Data(repeating: 0, count: leadingZeroCount) + Data(decoded)
        guard raw.count == 25 else { throw TronAddressError.invalidLength }
        let payload = raw.prefix(21)
        guard payload.first == 0x41 else { throw TronAddressError.invalidPrefix }
        let checksum = SHA256.hash(data: Data(SHA256.hash(data: payload))).prefix(4)
        guard Data(checksum) == Data(raw.suffix(4)) else { throw TronAddressError.invalidChecksum }
        return Data(payload.dropFirst())
    }
}

enum OperationEncoder {
    static let chainID: UInt64 = 3_448_148_188
    static let type = "P256WalletOperation(address wallet,uint256 chainId,address to,uint256 value,bytes32 dataHash,uint256 nonce,uint256 deadline)"

    static func sha256(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }

    static func addressWord(_ address: String) throws -> Data {
        try TronAddress.evmBytes(address).leftPadded(to: 32)
    }

    static func signingPayload(wallet: String, destination: String, valueSun: UInt64, data: Data, nonce: UInt64, deadline: UInt64) throws -> Data {
        var encoded = Data()
        encoded += sha256(Data(type.utf8))
        encoded += try addressWord(wallet)
        encoded += chainID.abiWord
        encoded += try addressWord(destination)
        encoded += valueSun.abiWord
        encoded += sha256(data)
        encoded += nonce.abiWord
        encoded += deadline.abiWord
        return encoded
    }

    static func digest(wallet: String, destination: String, valueSun: UInt64, data: Data, nonce: UInt64, deadline: UInt64) throws -> Data {
        sha256(try signingPayload(wallet: wallet, destination: destination, valueSun: valueSun, data: data, nonce: nonce, deadline: deadline))
    }
}
