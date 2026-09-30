import Foundation
import Security

/// Small Keychain wrapper. Gate and alarm codes, the vault key and the
/// founding-member unlock all live here, never in SwiftData.
struct KeychainService {
    static let shared = KeychainService()
    private let service = "co.petitehome.app"

    enum Key: String {
        case gateCode = "familyfile.gateCode"
        case alarmCode = "familyfile.alarmCode"
        case vaultKey = "vault.key.v1"
        case foundingUnlock = "premium.founding"
        case localTrial = "premium.localTrial"
        case deviceKey = "codes.key.v1"
    }

    func set(_ data: Data, for key: Key, synchronizable: Bool = false) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        if synchronizable { query[kSecAttrSynchronizable as String] = kCFBooleanTrue }
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = synchronizable
            ? kSecAttrAccessibleAfterFirstUnlock
            : kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func data(for key: Key, synchronizable: Bool = false) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if synchronizable { query[kSecAttrSynchronizable as String] = kCFBooleanTrue }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    func setString(_ value: String, for key: Key, synchronizable: Bool = false) {
        set(Data(value.utf8), for: key, synchronizable: synchronizable)
    }

    func string(for key: Key, synchronizable: Bool = false) -> String? {
        data(for: key, synchronizable: synchronizable).flatMap { String(data: $0, encoding: .utf8) }
    }

    func remove(_ key: Key, synchronizable: Bool = false) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        if synchronizable { query[kSecAttrSynchronizable as String] = kCFBooleanTrue }
        SecItemDelete(query as CFDictionary)
    }
}

/// Gate and alarm codes: the one exception to "never store a code". They are
/// sealed with a key that lives only in the iCloud Keychain (so the same Apple
/// ID can read them on every device) and never touch the SwiftData store.
enum SecureCodes {
    static func save(_ code: String, for key: KeychainService.Key) throws {
        guard key == .gateCode || key == .alarmCode else { return }
        if code.isEmpty {
            KeychainService.shared.remove(key, synchronizable: true)
            return
        }
        let sealed = try VaultCrypto.seal(Data(code.utf8), with: VaultCrypto.deviceKey())
        KeychainService.shared.set(sealed, for: key, synchronizable: true)
    }

    static func read(_ key: KeychainService.Key) -> String? {
        guard let sealed = KeychainService.shared.data(for: key, synchronizable: true) else { return nil }
        guard let plain = try? VaultCrypto.open(sealed, with: VaultCrypto.deviceKey()) else { return nil }
        return String(data: plain, encoding: .utf8)
    }
}
