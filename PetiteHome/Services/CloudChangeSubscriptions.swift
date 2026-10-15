import Foundation
import CloudKit

/// Silent pushes when the household changes in iCloud, so a chore the partner
/// adds reaches this phone within seconds instead of at the next open. One
/// database subscription on the shared database (the partner's changes) and
/// one on the private database (this person's other devices). Saved once.
enum CloudChangeSubscriptions {
    private static let savedKey = "ck.databaseSubscriptions.v1"

    static func ensure() {
        guard !UserDefaults.standard.bool(forKey: savedKey) else { return }
        let container = CKContainer(identifier: PersistenceController.cloudContainerID)
        let group = DispatchGroup()
        var allSaved = true
        for (db, id) in [(container.sharedCloudDatabase, "shared-db-changes"), (container.privateCloudDatabase, "private-db-changes")] {
            let subscription = CKDatabaseSubscription(subscriptionID: id)
            let info = CKSubscription.NotificationInfo()
            info.shouldSendContentAvailable = true
            subscription.notificationInfo = info
            let op = CKModifySubscriptionsOperation(subscriptionsToSave: [subscription], subscriptionIDsToDelete: nil)
            op.qualityOfService = .utility
            group.enter()
            op.modifySubscriptionsResultBlock = { result in
                if case .failure = result { allSaved = false }
                group.leave()
            }
            db.add(op)
        }
        group.notify(queue: .main) { if allSaved { UserDefaults.standard.set(true, forKey: savedKey) } }
    }
}
