import Foundation

enum HexError: Error { case invalid }

extension Data {
    init(hex: String) throws {
        let clean = hex.hasPrefix("0x") ? String(hex.dropFirst(2)) : hex
        guard clean.count.isMultiple(of: 2), clean.allSatisfy({ $0.isHexDigit }) else { throw HexError.invalid }
        var bytes = [UInt8](); bytes.reserveCapacity(clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else { throw HexError.invalid }
            bytes.append(byte); index = next
        }
        self.init(bytes)
    }

    var hex: String { "0x" + map { String(format: "%02x", $0) }.joined() }
    func leftPadded(to count: Int) throws -> Data {
        guard self.count <= count else { throw HexError.invalid }
        return Data(repeating: 0, count: count - self.count) + self
    }
}

extension UInt64 {
    var abiWord: Data {
        var value = bigEndian
        return Data(repeating: 0, count: 24) + Swift.withUnsafeBytes(of: &value) { Data($0) }
    }
}
