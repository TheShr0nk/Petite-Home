import Foundation
import CloudKit

/// Trusted Person sharing (premium): a read-only, time-limited link to a
/// rendered copy of the Family File, with the vault appended when allowed.
///
/// No backend. The rendered PDF is saved as a CKAsset on a record in a private
/// zone, wrapped in a CKShare with public read-only permission. The share URL
/// is the link. Anyone with the app can open it; the owner's app deletes the
/// share after `expiresAt`, which revokes the link everywhere.
final class TrustedShareService {
    static let shared = TrustedShareService()
    private let container = CKContainer(identifier: PersistenceController.cloudContainerID)
    private let zoneID = CKRecordZone.ID(zoneName: "TrustedShares", ownerName: CKCurrentUserDefaultName)
    static let recordType = "SharedFamilyFile"

    enum ShareError: LocalizedError {
        case noURL
        var errorDescription: String? { "The link couldn't be made. Try again in a moment." }
    }

    private func ensureZone() async throws {
        let db = container.privateCloudDatabase
        do {
            _ = try await db.recordZone(for: zoneID)
        } catch {
            _ = try await db.save(CKRecordZone(zoneID: zoneID))
        }
    }

    /// Uploads the PDF and returns the public read-only link plus the record name for revocation.
    func createShare(pdf: Data, title: String, recipientName: String, expiresAt: Date?) async throws -> (url: URL, recordName: String) {
        try await ensureZone()
        let tmp = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).pdf")
        try pdf.write(to: tmp, options: .completeFileProtection)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let record = CKRecord(recordType: Self.recordType, recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
        record["title"] = title
        record["recipientName"] = recipientName
        record["file"] = CKAsset(fileURL: tmp)
        if let expiresAt { record["expiresAt"] = expiresAt }

        let share = CKShare(rootRecord: record)
        share.publicPermission = .readOnly
        share[CKShare.SystemFieldKey.title] = title

        let op = CKModifyRecordsOperation(recordsToSave: [record, share], recordIDsToDelete: nil)
        op.savePolicy = .allKeys
        let saved: [CKRecord] = try await withCheckedThrowingContinuation { continuation in
            var results: [CKRecord] = []
            op.perRecordSaveBlock = { _, result in
                if case .success(let r) = result { results.append(r) }
            }
            op.modifyRecordsResultBlock = { result in
                switch result {
                case .success: continuation.resume(returning: results)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            container.privateCloudDatabase.add(op)
        }
        guard let savedShare = saved.compactMap({ $0 as? CKShare }).first, let url = savedShare.url else {
            throw ShareError.noURL
        }
        return (url, record.recordID.recordName)
    }

    /// Deletes the root record, which takes the share and the link with it.
    func revoke(recordName: String) async {
        let id = CKRecord.ID(recordName: recordName, zoneID: zoneID)
        _ = try? await container.privateCloudDatabase.deleteRecord(withID: id)
    }

    /// Recipient side: fetch the shared PDF after accepting the share.
    func fetchSharedFile(metadata: CKShare.Metadata) async throws -> (title: String, pdf: Data)? {
        let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success: continuation.resume()
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            container.add(op)
        }
        guard let rootID = metadata.hierarchicalRootRecordID else { return nil }
        let record = try await container.sharedCloudDatabase.record(for: rootID)
        if let expires = record["expiresAt"] as? Date, expires < Date() { return nil }
        guard let asset = record["file"] as? CKAsset, let url = asset.fileURL else { return nil }
        let data = try Data(contentsOf: url)
        return (record["title"] as? String ?? "Family File", data)
    }
}
