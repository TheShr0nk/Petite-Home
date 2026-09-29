import Foundation
import CloudKit

/// Who this phone belongs to, as far as iCloud is concerned. CloudKit gives
/// every iCloud account a stable, opaque user record name; that is the app's
/// identity, so there is no sign-in screen and no account to delete.
enum CloudIdentity {
    private static let cacheKey = "cloud.userRecordName"

    /// The cached identity, if a fetch has succeeded before.
    static var cachedUserID: String? {
        get { UserDefaults.standard.string(forKey: cacheKey) }
        set { UserDefaults.standard.set(newValue, forKey: cacheKey) }
    }

    /// True when the phone is signed into iCloud at all. Without it the app is local-only.
    static var isICloudAvailable: Bool { FileManager.default.ubiquityIdentityToken != nil }

    /// Fetches the user record name, or returns a per-install fallback so the app still works offline or with iCloud off.
    static func userID() async -> String {
        if let cached = cachedUserID { return cached }
        if isICloudAvailable,
           let record = try? await CKContainer(identifier: PersistenceController.cloudContainerID).userRecordID() {
            cachedUserID = record.recordName
            return record.recordName
        }
        let local = "local-\(UUID().uuidString)"
        cachedUserID = local
        return local
    }
}
