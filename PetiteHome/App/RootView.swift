import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var households: [Household]

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding, let household = currentHousehold {
                if appState.partnerWelcomePending {
                    PartnerWelcomeFlow(household: household)
                } else {
                    MainTabView(household: household)
                }
            } else {
                OnboardingFlow()
            }
        }
        .screenBackground()
        .onAppear(perform: repairHouseholdSelection)
        .onChange(of: households.count) { _, _ in repairHouseholdSelection() }
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
            if first.ownerUserID != nil {
                if !appState.hasCompletedOnboarding, first.ownerUserID != CloudIdentity.cachedUserID {
                    appState.partnerWelcomePending = true
                }
                appState.hasCompletedOnboarding = true
            }
        }
    }
}
