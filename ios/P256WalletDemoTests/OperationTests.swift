import XCTest
@testable import P256WalletDemo

final class OperationTests: XCTestCase {
    func testSharedDigestVector() throws {
        let digest = try OperationEncoder.digest(
            wallet: "TBXSw8fM4jpQkGc6zZjsVABFpVN7UvXPdV",
            destination: "TD5gsCwxykWsLN9aPrq2TAfNjByuZKYp4E",
            valueSun: 1_234_567, data: try Data(hex: "0x12345678"), nonce: 0, deadline: 2_000_000_000
        )
        XCTAssertEqual(digest.hex, "0x85e1b4fdda9d036e24f5fa6192858c398c59b7c2fa79ada2b3abafec747416d0")
    }

    func testAddressValidation() {
        XCTAssertThrowsError(try OperationEncoder.addressWord("0x1111111111111111111111111111111111111111"))
        XCTAssertThrowsError(try OperationEncoder.addressWord("TBXSw8fM4jpQkGc6zZjsVABFpVN7UvXPdW"))
    }

    func testBase58AddressDecoding() throws {
        XCTAssertEqual(
            try TronAddress.evmBytes("TPt83tvjrFjKTPTv8AEZEk4KabHvcEWVQV").hex,
            "0x989b8c5747943f0826396dbd7c57abc3b4b3ebb0"
        )
        XCTAssertEqual(
            Data(try OperationEncoder.addressWord("TBXSw8fM4jpQkGc6zZjsVABFpVN7UvXPdV").suffix(20)).hex,
            "0x1111111111111111111111111111111111111111"
        )
    }
}
