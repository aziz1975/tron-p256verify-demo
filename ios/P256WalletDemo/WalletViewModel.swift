import Combine
import Foundation

@MainActor
final class WalletViewModel: ObservableObject {
    @Published var relayerURL = "http://192.168.1.19:8787"
    @Published var wallet = "0x989b8c5747943f0826396dbd7c57abc3b4b3ebb0"
    @Published var destination = ""
    @Published var valueSun = "0"
    @Published var nonce = "0"
    @Published var status = "Create a key to begin"
    @Published var publicKey = ""
    private var signer: P256Signer?

    func createKey() {
        do {
#if targetEnvironment(simulator)
            signer = SoftwareP256Signer()
            status = "Software test key (Simulator)"
#else
            signer = try SecureEnclaveP256Signer()
            status = "Secure Enclave key ready"
#endif
            publicKey = signer?.publicKeyX963.hex ?? ""
        } catch { status = "Key error: \(error.localizedDescription)" }
    }

    func signAndRelay() async {
        do {
            guard let signer else { throw NSError(domain: "Demo", code: 1, userInfo: [NSLocalizedDescriptionKey: "Create a key first"]) }
            guard let value = UInt64(valueSun), let operationNonce = UInt64(nonce) else { throw HexError.invalid }
            let deadline = UInt64(Date().timeIntervalSince1970) + 300
            let calldata = Data()
            let signingPayload = try OperationEncoder.signingPayload(wallet: wallet, destination: destination, valueSun: value, data: calldata, nonce: operationNonce, deadline: deadline)
            let signature = try signer.sign(message: signingPayload)
            let operation = WalletOperation(wallet: wallet, destination: destination, valueSun: String(value), data: calldata.hex, nonce: String(operationNonce), deadline: String(deadline), r: signature.r.hex, s: signature.s.hex)
            var request = URLRequest(url: URL(string: relayerURL + "/relay")!)
            request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(operation)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "Relayer", code: 2, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? "Relay failed"])
            }
            status = "Submitted: \(String(data: data, encoding: .utf8) ?? "")"
        } catch { status = "Error: \(error.localizedDescription)" }
    }
}
