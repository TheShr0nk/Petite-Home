import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Query private var households: [Household]

    var body: some View {
        Group {
            if appState.hasCompletedOnboarding, currentHousehold != nil {
                MainTabView(household: currentHousehold!)
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
    private func repairHouseholdSelection() {
        if appState.currentHouseholdID == nil, let first = households.first {
            appState.currentHouseholdID = first.uuid
            if first.ownerUserID != nil { appState.hasCompletedOnboarding = true }
        }
    }
}
