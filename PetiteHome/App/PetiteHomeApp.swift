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
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(entitlements)
                .preferredColorScheme(.light)   // the brand is light; no dark mode in v1
                .tint(Theme.Colors.powderBlueDk)
                .onOpenURL { appState.handle(url: $0) }
                .task { await entitlements.loadProducts() }
                .onAppear { appDelegate.appState = appState }
        }
        .modelContainer(PersistenceController.shared)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var appState: AppState?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // Force light appearance everywhere, including UIKit-hosted sheets.
        UIWindow.appearance().overrideUserInterfaceStyle = .light
        return true
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
    static let didReceiveSharedFile = Notification.Name("co.petitehome.didReceiveSharedFile")
}
