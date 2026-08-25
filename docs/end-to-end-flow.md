# Detailed end-to-end sequence

This diagram shows the one-time key and wallet setup followed by every step of an approved operation. Time moves from top to bottom.

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as iOS App
    participant SE as Secure Enclave
    participant Operator as Wallet Deployer
    participant Relay as Relayer Server
    participant Nile as TRON Nile Network
    participant Wallet as P256 Smart Wallet
    participant Target as Destination

    rect rgb(235, 245, 255)
        Note over User,Wallet: One-time key and wallet setup
        User->>App: Tap Create or load signing key
        App->>SE: Load the existing P-256 key
        alt No existing key
            SE->>SE: Generate a new P-256 private key
            SE-->>App: Return an opaque key reference
            App->>App: Save the reference in Keychain
        else Existing key found
            SE-->>App: Reconnect to the protected key
        end
        SE-->>App: Return public key 04 + x + y
        App-->>User: Display the public key
        User->>Operator: Provide public x and y
        Operator->>Nile: Deploy wallet with public x and y
        Nile->>Wallet: Store publicKeyX and publicKeyY
        Note over SE,Wallet: The private key stays in the Secure Enclave. Only the public key is stored on-chain.
    end

    rect rgb(240, 255, 240)
        Note over User,Target: Every Approve, sign, and relay operation
        User->>App: Enter wallet, destination, SUN value, and nonce
        User->>App: Tap Approve, sign, and relay
        App->>App: Add 5-minute deadline and encode operation
        App->>SE: Request P-256 signature
        SE-->>User: Ask for Face ID or passcode
        User-->>SE: Approve
        SE->>SE: Hash and sign inside Secure Enclave
        SE-->>App: Return signature r and s only
        App->>Relay: POST /relay with operation, r, and s
        Relay->>Wallet: Read nonce, publicKeyX, and publicKeyY
        Wallet-->>Relay: Return current values
        Relay->>Relay: Check format, nonce, and deadline
        Relay->>Relay: Rebuild digest and verify P-256 signature

        alt Relayer check fails
            Relay-->>App: Reject request with an error
            App-->>User: Display Error
        else Relayer check passes
            Relay->>Relay: Sign outer transaction with NILE_PRIVATE_KEY
            Relay->>Nile: Broadcast wallet.execute and pay resource costs
            Nile-->>Relay: Return transaction ID
            Relay-->>App: Return transaction ID and digest
            App-->>User: Display Submitted
            Nile->>Wallet: Execute destination, value, data, nonce, deadline, r, s
            Wallet->>Wallet: Check nonce and deadline
            Wallet->>Wallet: Rebuild the operation digest
            Wallet->>Nile: Verify digest, r, s, x, y at P256VERIFY 0x100
            Nile-->>Wallet: Valid or invalid

            alt Wallet validation fails
                Wallet-->>Nile: Revert transaction
            else Wallet validation passes
                Wallet->>Wallet: Increment nonce
                Wallet->>Target: Call with data and wallet funds
                alt Destination call fails
                    Target-->>Wallet: Revert
                    Wallet-->>Nile: Revert and restore nonce
                else Destination call succeeds
                    Target-->>Wallet: Return result
                    Wallet->>Wallet: Emit Executed event
                    Wallet-->>Nile: Commit successful execution
                end
            end
            Note over User,Nile: Submitted is not final. Check the Nile receipt for SUCCESS or REVERT.
        end
    end
```

The user P-256 signature proves approval of the exact wallet operation. The separate relayer TRON signature authorizes and pays for broadcasting the outer transaction. `Submitted` only means the transaction was broadcast; check the Nile receipt for `SUCCESS` or `REVERT`.
