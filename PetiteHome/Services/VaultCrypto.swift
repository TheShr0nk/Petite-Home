import Foundation
import CryptoKit

/// Client-side encryption for the document vault.
///
/// A 256-bit AES-GCM key is generated once per household owner and stored in
/// the iCloud Keychain (synchronizable), so the same Apple ID can open the
/// vault on every device. Blobs are sealed before they are handed to SwiftData,
/// so CloudKit only ever carries ciphertext.
///
/// Sharing the vault with a partner on a different Apple ID needs the key
/// wrapped for them; that is tracked as a follow-up, not in v1.
final class VaultCrypto {
    static let shared = VaultCrypto()
    static let currentKeyIdentifier = "v1"

    enum CryptoError: Error { case noKey, malformed }

    private var cachedKey: SymmetricKey?

    private init() {}

    func key() throws -> SymmetricKey {
        if let cachedKey { return cachedKey }
        if let data = KeychainService.shared.data(for: .vaultKey, synchronizable: true) {
            let k = SymmetricKey(data: data)
            cachedKey = k
            return k
        }
        let k = SymmetricKey(size: .bits256)
        let raw = k.withUnsafeBytes { Data($0) }
        KeychainService.shared.set(raw, for: .vaultKey, synchronizable: true)
        cachedKey = k
        return k
    }

    /// Returns nonce || ciphertext || tag (the AES.GCM combined representation).
    func seal(_ plaintext: Data) throws -> Data {
        let box = try AES.GCM.seal(plaintext, using: try key())
        guard let combined = box.combined else { throw CryptoError.malformed }
        return combined
    }

    func open(_ combined: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: try key())
    }

    // Pure helpers with an explicit key, used by the unit tests.
    static func seal(_ plaintext: Data, with key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(plaintext, using: key).combined else { throw CryptoError.malformed }
        return combined
    }
    static func open(_ combined: Data, with key: SymmetricKey) throws -> Data {
        try AES.GCM.open(try AES.GCM.SealedBox(combined: combined), using: key)
    }
}
