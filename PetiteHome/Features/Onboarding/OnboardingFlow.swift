import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case hook, household, firstContact, pediatrician, insurance, guardian, reveal, partnerInvite, premium

    var analyticsName: String {
        switch self {
        case .hook: return "hook"
        case .household: return "household"
        case .firstContact: return "first_contact"
        case .pediatrician: return "pediatrician"
        case .insurance: return "insurance"
        case .guardian: return "guardian"
        case .reveal: return "reveal"
        case .partnerInvite: return "partner_invite"
        case .premium: return "premium"
        }
    }
}

/// Every screen does one thing. Progress bar at top, back button everywhere.
/// The hook can't be skipped; everything after it can.
struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @State private var draft = OnboardingDraft()
    @State private var step: OnboardingStep = .hook
    @State private var savedHousehold: Household?

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch step {
                case .hook: HookScreen { advance() }
                case .household: HouseholdScreen(draft: draft) { advance() }
                case .firstContact: FirstContactScreen(draft: draft) { advance() }
                case .pediatrician: PediatricianScreen(draft: draft) { advance() }
                case .insurance: InsuranceScreen(draft: draft) { advance() }
                case .guardian: GuardianScreen(draft: draft) { advance() }
                case .reveal: RevealScreen(draft: draft) { household in
                    savedHousehold = household
                    appState.currentHouseholdID = household.id
                    advance()
                }
                case .partnerInvite: PartnerInviteScreen(household: savedHousehold, partnerName: draft.partnerFirstName) { advance() }
                case .premium: PremiumOfferScreen { finish() }
                }
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            .id(step)
        }
        .screenBackground()
        .onChange(of: step, initial: true) { _, new in
            Analytics.track(.onboardingStepViewed, ["step": new.analyticsName])
        }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button {
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.sandDeep)
                    .frame(width: 40, height: 40)
            }
            .opacity(step == .hook || step.rawValue > OnboardingStep.reveal.rawValue ? 0 : 1)
            .disabled(step == .hook || step.rawValue > OnboardingStep.reveal.rawValue)
            ProgressBar(progress: Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count))
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.28)) {
            if let next = OnboardingStep(rawValue: step.rawValue + 1) { step = next } else { finish() }
        }
    }

    private func back() {
        withAnimation(.easeInOut(duration: 0.28)) {
            if let prev = OnboardingStep(rawValue: step.rawValue - 1) { step = prev }
        }
    }

    private func finish() {
        appState.premiumOfferSeenInOnboarding = true
        Analytics.track(.onboardingCompleted)
        appState.selectedTab = .home
        appState.hasCompletedOnboarding = true
    }
}

/// Shared frame for every onboarding screen: hook copy top-left, content, actions pinned to the bottom.
struct OnboardingScreen<Content: View, Actions: View>: View {
    let hook: String
    var subline: String? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Text(hook)
                            .font(Typography.hook)
                            .lineSpacing(7)
                            .foregroundStyle(Theme.Colors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subline {
                            Text(subline)
                                .font(Typography.body)
                                .foregroundStyle(Theme.Colors.sandDeep)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.top, Theme.Spacing.xxl)
                    content()
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: Theme.Spacing.sm) {
                actions()
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }
}
