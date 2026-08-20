import XCTest
@testable import P256WalletDemo

final class OperationTests: XCTestCase {
    func testSharedDigestVector() throws {
        let digest = try OperationEncoder.digest(
            wallet: "0x1111111111111111111111111111111111111111",
            destination: "0x2222222222222222222222222222222222222222",
            valueSun: 1_234_567, data: try Data(hex: "0x12345678"), nonce: 0, deadline: 2_000_000_000
        )
        XCTAssertEqual(digest.hex, "0x85e1b4fdda9d036e24f5fa6192858c398c59b7c2fa79ada2b3abafec747416d0")
    }

    func testAddressValidation() {
        XCTAssertThrowsError(try OperationEncoder.addressWord("TNotAHexAddress"))
    }
}

