import SwiftUI
import SwiftData

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Bindable var household: Household

    var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            NavigationStack { HomeView(household: household) }
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            FamilyFileView(household: household)
                .tabItem { Label(AppCopy.binder, systemImage: "book.closed") }
                .tag(AppTab.familyFile)
            NavigationStack { LifeSyncView(household: household) }
                .tabItem { Label(AppCopy.planner, systemImage: "calendar") }
                .tag(AppTab.lifeSync)
            NavigationStack { VaultView(household: household) }
                .tabItem { Label("Vault", systemImage: "lock.doc") }
                .tag(AppTab.vault)
        }
        .sheet(item: $appState.paywallGate) { gate in
            PaywallSheet(gate: gate)
        }
        .sheet(isPresented: $appState.showSettings) {
            NavigationStack { SettingsView(household: household) }
        }
        .onAppear(perform: onLaunch)
        .onReceive(NotificationCenter.default.publisher(for: .didReceiveSharedFile)) { note in
            if let title = note.userInfo?["title"] as? String, let pdf = note.userInfo?["pdf"] as? Data {
                appState.pendingSharedFile = (title, pdf)
            }
        }
        .sheet(isPresented: Binding(get: { appState.pendingSharedFile != nil }, set: { if !$0 { appState.pendingSharedFile = nil } })) {
            if let shared = appState.pendingSharedFile {
                SharedFileViewer(title: shared.title, pdf: shared.pdf)
            }
        }
    }

    private func onLaunch() {
        let report = Completeness.report(file: household.familyFile, household: household)
        Analytics.track(.familyFileCompleteness, ["bucket": report.bucket])
        Task {
            // Nudges only go out once the user has granted permission (asked when they first tap a reminder or the nudge card).
            if await NotificationService.shared.authorizationStatus() == .authorized {
                NotificationService.shared.scheduleNudgeIfNeeded(percent: report.percent, next: report.nextToAdd.first)
            }
        }
        expireTrustedShares()
        UITabBar.appearance().unselectedItemTintColor = UIColor(hex: 0x6E6259)
    }

    /// Time-limited links: revoke anything past its date.
    private func expireTrustedShares() {
        for trusted in household.trustedContacts ?? [] where trusted.isExpired && trusted.shareRecordName != nil {
            let name = trusted.shareRecordName!
            Task { await TrustedShareService.shared.revoke(recordName: name) }
            trusted.shareRecordName = nil
            trusted.shareLink = nil
        }
    }
}

extension PremiumGate: Identifiable {
    var id: String { rawValue }
}
