import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Query private var households: [Household]
    @State private var shareError: String?

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding, let household = currentHousehold {
                if appState.partnerWelcomePending {
                    PartnerWelcomeFlow(household: household)
                } else if !entitlements.isPremium {
                    // The hard wall: a lapsed or never-started subscription sees the plans,
                    // restore, and the Founding 500 code. The data stays; the tabs wait.
                    PaywallSheet(gate: .onboarding, dismissible: false)
                        .screenBackground()
                        .task { await entitlements.restore() }
                } else {
                    MainTabView(household: household)
                }
            } else if appState.awaitingSharedHousehold {
                SharedHouseholdSyncScreen(error: shareError) {
                    shareError = nil
                    appState.awaitingSharedHousehold = false
                }
            } else {
                OnboardingFlow()
            }
        }
        .screenBackground()
        .onAppear(perform: repairHouseholdSelection)
        .onChange(of: households.count) { _, _ in repairHouseholdSelection() }
        .onReceive(NotificationCenter.default.publisher(for: .partnerShareAccepting)) { _ in
            shareError = nil
            if households.isEmpty { appState.awaitingSharedHousehold = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .partnerShareFailed)) { note in
            shareError = note.userInfo?["message"] as? String ?? "The invite couldn't be opened."
        }
    }

    private var currentHousehold: Household? {
        if let id = appState.currentHouseholdID, let h = households.first(where: { $0.uuid == id }) { return h }
        return households.first
    }

    /// Onboarding done on another device, or the household arrived via sync: pick it up.
    /// A household someone else created means this phone belongs to the partner, so
    /// they get the short welcome (which one are you, your calendar, reminders).
    private func repairHouseholdSelection() {
        if appState.currentHouseholdID == nil, let first = households.first {
            appState.currentHouseholdID = first.uuid
            appState.awaitingSharedHousehold = false
            if first.ownerUserID != nil {
                if !appState.hasCompletedOnboarding, first.ownerUserID != CloudIdentity.cachedUserID {
                    appState.partnerWelcomePending = true
                }
                appState.hasCompletedOnboarding = true
            }
        }
    }
}
