import CryptoKit
import Foundation
import LocalAuthentication
import Security

protocol P256Signer {
    var publicKeyX963: Data { get }
    func sign(message: Data) throws -> (r: Data, s: Data)
}

enum SignerError: Error { case secureEnclaveUnavailable, invalidSignature }

private let p256Order = try! Data(hex: "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551")
private let p256HalfOrder = try! Data(hex: "7fffffff800000007fffffffffffffffde737d56d38bcf4c27a1dce5617e3192a8")

private func compare(_ a: Data, _ b: Data) -> Int {
    for (x, y) in zip(a, b) { if x != y { return x < y ? -1 : 1 } }
    return 0
}

private func subtract(_ a: Data, _ b: Data) -> Data {
    var result = [UInt8](repeating: 0, count: a.count), borrow = 0
    let aa = [UInt8](a), bb = [UInt8](b)
    for i in stride(from: a.count - 1, through: 0, by: -1) {
        var value = Int(aa[i]) - Int(bb[i]) - borrow
        if value < 0 { value += 256; borrow = 1 } else { borrow = 0 }
        result[i] = UInt8(value)
    }
    return Data(result)
}

private func normalizedRaw(_ raw: Data) throws -> (Data, Data) {
    guard raw.count == 64 else { throw SignerError.invalidSignature }
    let r = raw.prefix(32), originalS = raw.suffix(32)
    let s = compare(Data(originalS), p256HalfOrder) > 0 ? subtract(p256Order, Data(originalS)) : Data(originalS)
    return (Data(r), s)
}

final class SecureEnclaveP256Signer: P256Signer {
    private let key: SecureEnclave.P256.Signing.PrivateKey
    private static let account = "secure-enclave-p256-key"

    init() throws {
        guard SecureEnclave.isAvailable else { throw SignerError.secureEnclaveUnavailable }
        if let saved = Self.load() {
            key = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: saved)
        } else {
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleWhenUnlockedThisDeviceOnly, [.privateKeyUsage, .userPresence], &error) else {
                throw error!.takeRetainedValue() as Error
            }
            key = try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
            try Self.save(key.dataRepresentation)
        }
    }

    var publicKeyX963: Data { key.publicKey.x963Representation }

    func sign(message: Data) throws -> (r: Data, s: Data) {
        let signature = try key.signature(for: message)
        return try normalizedRaw(signature.rawRepresentation)
    }

    private static func load() -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account, kSecReturnData as String: true]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func save(_ data: Data) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: account, kSecValueData as String: data]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }
    }
}

final class SoftwareP256Signer: P256Signer {
    private let key = P256.Signing.PrivateKey()
    var publicKeyX963: Data { key.publicKey.x963Representation }
    func sign(message: Data) throws -> (r: Data, s: Data) {
        return try normalizedRaw(key.signature(for: message).rawRepresentation)
    }
}
