import SwiftUI

struct ContentView: View {
    @StateObject private var model = WalletViewModel()

    var body: some View {
        NavigationStack {
            Form {
                Section("P-256 key") {
                    Button("Create or load signing key") { model.createKey() }
                    if !model.publicKey.isEmpty { Text(model.publicKey).font(.caption).textSelection(.enabled) }
                }
                Section("Nile operation (20-byte hex addresses)") {
                    TextField("Relayer URL", text: $model.relayerURL).textInputAutocapitalization(.never)
                    TextField("Wallet 0x address", text: $model.wallet).textInputAutocapitalization(.never)
                    TextField("Destination 0x address", text: $model.destination).textInputAutocapitalization(.never)
                    TextField("Value in SUN", text: $model.valueSun).keyboardType(.numberPad)
                    TextField("Wallet nonce", text: $model.nonce).keyboardType(.numberPad)
                    Button("Approve, sign, and relay") { Task { await model.signAndRelay() } }
                }
                Section("Status") { Text(model.status).textSelection(.enabled) }
                Section { Text("Demo only. Never use real-value keys or funds.").foregroundStyle(.red) }
            }
            .navigationTitle("P256 Nile Demo")
        }
    }
}

