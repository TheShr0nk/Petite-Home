import SwiftUI
import SwiftData
import CloudKit
import UserNotifications

@main
struct PetiteHomeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var entitlements = EntitlementStore.shared

    init() {
        Analytics.start()
        EntitlementStore.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(entitlements)
                .preferredColorScheme(appState.appearance.colorScheme)
                .tint(Theme.Colors.accentText)
                .onOpenURL { appState.handle(url: $0) }
                .onAppear { appDelegate.appState = appState }
        }
        .modelContainer(PersistenceController.shared)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var appState: AppState?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Silent CloudKit pushes wake the app when the partner changes something.
        application.registerForRemoteNotifications()
        CloudChangeSubscriptions.ensure()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    /// A silent push from CloudKit. Give SwiftData a moment to import, then let the tabs react.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else { return .noData }
        try? await Task.sleep(for: .seconds(4))
        await MainActor.run { NotificationCenter.default.post(name: .cloudChangesArrived, object: nil) }
        return .newData
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    // Notification taps deep link into the Family File.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        if let link = response.notification.request.content.userInfo["deepLink"] as? String, let url = URL(string: link) {
            await MainActor.run { appState?.handle(url: url) }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

/// Receives CloudKit share acceptance for both partner invites and trusted-person links.
final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        Task { @MainActor in
            if cloudKitShareMetadata.share.recordID.zoneID.zoneName == "TrustedShares"
                || cloudKitShareMetadata.hierarchicalRootRecordID?.zoneID.zoneName == "TrustedShares" {
                if let result = try? await TrustedShareService.shared.fetchSharedFile(metadata: cloudKitShareMetadata) {
                    NotificationCenter.default.post(name: .didReceiveSharedFile, object: nil, userInfo: ["title": result.title, "pdf": result.pdf])
                }
            } else {
                CloudSharingService.shared.accept(cloudKitShareMetadata)
            }
        }
    }
}

extension Notification.Name {
    /// Posted after a silent CloudKit push, once the import has had a moment to land.
    static let cloudChangesArrived = Notification.Name("co.petitehome.cloudChangesArrived")
    static let didReceiveSharedFile = Notification.Name("co.petitehome.didReceiveSharedFile")
}
