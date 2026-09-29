import Foundation
import CryptoKit

/// Client-side encryption for the document vault.
///
/// Each household has one 256-bit AES-GCM key. It is stored on the Household
/// record in a field marked `.allowsCloudEncryption`, which CloudKit encrypts
/// end to end with keys derived from the users' iCloud Keychains and shares
/// with accepted participants. So the partner can open the vault, Petite Home
/// Co. never can, and neither can Apple.
///
/// A copy is cached in the iCloud Keychain so documents open offline. Gate and
/// alarm codes use a separate device key that is never written to a record.
enum VaultCrypto {
    static let currentKeyIdentifier = "v1"

    enum CryptoError: Error { case noKey, malformed }

    /// The household's key: from the record when synced, else the Keychain cache, else freshly made.
    @MainActor
    static func householdKey(for household: Household) -> SymmetricKey {
        if let data = household.vaultKey, data.count == 32 {
            KeychainService.shared.set(data, for: .vaultKey, synchronizable: true)
            return SymmetricKey(data: data)
        }
        if let cached = KeychainService.shared.data(for: .vaultKey, synchronizable: true), cached.count == 32 {
            household.vaultKey = cached
            return SymmetricKey(data: cached)
        }
        let fresh = SymmetricKey(size: .bits256)
        let raw = fresh.withUnsafeBytes { Data($0) }
        household.vaultKey = raw
        KeychainService.shared.set(raw, for: .vaultKey, synchronizable: true)
        return fresh
    }

    /// For gate and alarm codes only. Lives in the iCloud Keychain, never on a record.
    static func deviceKey() -> SymmetricKey {
        if let data = KeychainService.shared.data(for: .deviceKey, synchronizable: true), data.count == 32 {
            return SymmetricKey(data: data)
        }
        let fresh = SymmetricKey(size: .bits256)
        KeychainService.shared.set(fresh.withUnsafeBytes { Data($0) }, for: .deviceKey, synchronizable: true)
        return fresh
    }

    /// Returns nonce || ciphertext || tag (the AES.GCM combined representation).
    static func seal(_ plaintext: Data, with key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(plaintext, using: key).combined else { throw CryptoError.malformed }
        return combined
    }

    static func open(_ combined: Data, with key: SymmetricKey) throws -> Data {
        try AES.GCM.open(try AES.GCM.SealedBox(combined: combined), using: key)
    }
}
