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
                Section("Nile operation (TRON addresses)") {
                    LabeledField("Relayer URL", placeholder: "http://192.168.1.19:8787", text: $model.relayerURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    LabeledField("Wallet address", placeholder: "T…", text: $model.wallet)
                        .textInputAutocapitalization(.never)
                    LabeledField("Destination address", placeholder: "T…", text: $model.destination)
                        .textInputAutocapitalization(.never)
                    LabeledField("Value (SUN)", placeholder: "0", text: $model.valueSun)
                        .keyboardType(.numberPad)
                    LabeledField("Wallet nonce", placeholder: "0", text: $model.nonce)
                        .keyboardType(.numberPad)
                    Button("Approve, sign, and relay") { Task { await model.signAndRelay() } }
                }
                Section("Status") { Text(model.status).textSelection(.enabled) }
                Section { Text("Demo only. Never use real-value keys or funds.").foregroundStyle(.red) }
            }
            .navigationTitle("P256 Nile Demo")
        }
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    init(_ label: String, placeholder: String, text: Binding<String>) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .accessibilityLabel(label)
        }
    }
}
