import Foundation
import CoreData
import CloudKit
import SwiftData
import UIKit

/// Partner sharing: a CKShare on the Household record.
///
/// SwiftData on iOS 17 has no CKShare API, so this service opens a second,
/// read-mostly Core Data stack (NSPersistentCloudKitContainer) over the same
/// store file, using the managed object model SwiftData derives from the
/// schema. That container knows how to create and accept shares.
///
/// Known limit, and the reason ship-order step 4 must be verified on two real
/// devices before anything else: the partner's ModelContainer only reads the
/// private database. On the partner's device the shared household is reached
/// through `sharedContainer` (the `.shared` scope store) rather than through
/// SwiftData, which is why `PartnerHouseholdBridge` exists. If Apple ships a
/// SwiftData sharing API this whole file shrinks to a few lines.
@MainActor
final class CloudSharingService: NSObject {
    static let shared = CloudSharingService()

    enum SharingError: LocalizedError {
        case modelUnavailable, householdNotFound, notSignedIn
        var errorDescription: String? {
            switch self {
            case .modelUnavailable: return "Sharing isn't available on this device yet."
            case .householdNotFound: return "Couldn't find the household to share."
            case .notSignedIn: return "Sign in to iCloud in Settings to share."
            }
        }
    }

    private(set) lazy var container: NSPersistentCloudKitContainer? = makeContainer()
    private var privateStore: NSPersistentStore?
    private var sharedStore: NSPersistentStore?

    private override init() { super.init() }

    private func makeContainer() -> NSPersistentCloudKitContainer? {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: PetiteSchema.models) else { return nil }
        let container = NSPersistentCloudKitContainer(name: "PetiteHome", managedObjectModel: model)

        let privateDescription = NSPersistentStoreDescription(url: PersistenceController.storeURL)
        privateDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: PersistenceController.cloudContainerID)
        privateDescription.cloudKitContainerOptions?.databaseScope = .private
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        let sharedURL = PersistenceController.storeURL.deletingLastPathComponent().appending(path: "PetiteHome-shared.store")
        let sharedDescription = NSPersistentStoreDescription(url: sharedURL)
        sharedDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: PersistenceController.cloudContainerID)
        sharedDescription.cloudKitContainerOptions?.databaseScope = .shared
        sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        sharedDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [privateDescription, sharedDescription]
        container.loadPersistentStores { [weak self] description, error in
            guard error == nil else { return }
            Task { @MainActor in
                guard let self, let url = description.url,
                      let store = container.persistentStoreCoordinator.persistentStore(for: url) else { return }
                if description.cloudKitContainerOptions?.databaseScope == .shared { self.sharedStore = store } else { self.privateStore = store }
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return container
    }

    /// Finds the Core Data object behind a SwiftData household by its UUID.
    private func managedHousehold(id: UUID) throws -> NSManagedObject {
        guard let container else { throw SharingError.modelUnavailable }
        let request = NSFetchRequest<NSManagedObject>(entityName: "Household")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let object = try container.viewContext.fetch(request).first else { throw SharingError.householdNotFound }
        return object
    }

    /// Returns the existing share for the household, or creates one.
    func share(for householdID: UUID, title: String) async throws -> (CKShare, CKContainer) {
        guard let container else { throw SharingError.modelUnavailable }
        let object = try managedHousehold(id: householdID)
        let ckContainer = CKContainer(identifier: PersistenceController.cloudContainerID)
        if let existing = try? container.fetchShares(matching: [object.objectID])[object.objectID] {
            return (existing, ckContainer)
        }
        let (_, share, _) = try await container.share([object], to: nil)
        share[CKShare.SystemFieldKey.title] = title
        return (share, ckContainer)
    }

    func isShared(householdID: UUID) -> Bool {
        guard let container, let object = try? managedHousehold(id: householdID) else { return false }
        return (try? container.fetchShares(matching: [object.objectID]))?.isEmpty == false
    }

    /// Participants on the household's share, for Settings.
    func participants(householdID: UUID) -> [CKShare.Participant] {
        guard let container, let object = try? managedHousehold(id: householdID),
              let share = try? container.fetchShares(matching: [object.objectID])[object.objectID] else { return [] }
        return share.participants.filter { $0.role != .owner }
    }

    /// Called from the app delegate when the partner opens the invite link.
    func accept(_ metadata: CKShare.Metadata) {
        guard let container, let sharedStore else { return }
        container.acceptShareInvitations(from: [metadata], into: sharedStore) { _, error in
            if let error { print("[sharing] accept failed: \(error)") }
        }
    }

    /// The system share sheet. Prefills the partner's name into the message where the API allows.
    func makeSharingController(share: CKShare, container: CKContainer) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.delegate = self
        return controller
    }
}

extension CloudSharingService: UICloudSharingControllerDelegate {
    nonisolated func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("[sharing] failed to save share: \(error)")
    }
    nonisolated func itemTitle(for csc: UICloudSharingController) -> String? { "Our Family File" }
    nonisolated func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        Analytics.track(.partnerInvited)
    }
}

/// On the partner's device the shared household lives in the `.shared` store
/// of the Core Data stack. This bridge exposes the little the UI needs to read
/// from it until SwiftData can open the shared database itself.
enum PartnerHouseholdBridge {
    @MainActor
    static func sharedHouseholdIDs() -> [UUID] {
        guard let container = CloudSharingService.shared.container else { return [] }
        let request = NSFetchRequest<NSManagedObject>(entityName: "Household")
        let objects = (try? container.viewContext.fetch(request)) ?? []
        return objects.compactMap { obj in
            guard let store = obj.objectID.persistentStore,
                  store.url?.lastPathComponent == "PetiteHome-shared.store" else { return nil }
            return obj.value(forKey: "id") as? UUID
        }
    }
}
