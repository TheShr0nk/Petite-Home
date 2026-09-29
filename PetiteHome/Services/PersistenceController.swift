import Foundation
import SwiftData

/// The SwiftData container. Syncs through the app's private CloudKit database;
/// the Household record is what gets shared with a partner (see CloudSharingService).
enum PersistenceController {
    static let cloudContainerID = "iCloud.co.petitehome.app"

    static let shared: ModelContainer = {
        let schema = Schema(PetiteSchema.models)
        let config = ModelConfiguration(
            "PetiteHome",
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudContainerID)
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // CloudKit is unavailable in previews and on simulators without an
            // account. Fall back to a local store so the app still runs.
            let local = ModelConfiguration("PetiteHome-local", schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: [local])
            } catch {
                fatalError("Could not open the data store: \(error)")
            }
        }
    }()

    static func preview() -> ModelContainer {
        let schema = Schema(PetiteSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try! ModelContainer(for: schema, configurations: [config])
    }

    /// The store file, needed by the sharing service to open a parallel Core Data stack.
    static var storeURL: URL {
        shared.configurations.first?.url
            ?? URL.applicationSupportDirectory.appending(path: "default.store")
    }
}
