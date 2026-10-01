import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case intro, hook, household, firstContact, pediatrician, insurance, guardian, reveal, partnerInvite, lifeSync, premium

    var analyticsName: String {
        switch self {
        case .intro: return "intro"
        case .hook: return "hook"
        case .household: return "household"
        case .firstContact: return "first_contact"
        case .pediatrician: return "pediatrician"
        case .insurance: return "insurance"
        case .guardian: return "guardian"
        case .reveal: return "reveal"
        case .partnerInvite: return "partner_invite"
        case .lifeSync: return "life_sync"
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
    @State private var step: OnboardingStep = .intro
    @State private var savedHousehold: Household?
    @State private var showSavedMoment = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                header
                screens
            }
            if showSavedMoment {
                SavedMomentScreen(household: savedHousehold) { completeOnboarding() }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .screenBackground()
        .onChange(of: step, initial: true) { _, new in
            Analytics.track(.onboardingStepViewed, ["step": new.analyticsName])
        }
    }

    private var screens: some View {
        ZStack {
            Group {
                switch step {
                case .intro: IntroScreen { advance() }
                case .hook: HookScreen { advance() }
                case .household: HouseholdScreen(draft: draft) { advance() }
                case .firstContact: FirstContactScreen(draft: draft) { advance() }
                case .pediatrician: PediatricianScreen(draft: draft) { advance() }
                case .insurance: InsuranceScreen(draft: draft) { advance() }
                case .guardian: GuardianScreen(draft: draft) { advance() }
                case .reveal: RevealScreen(draft: draft) { household in
                    savedHousehold = household
                    appState.currentHouseholdID = household.uuid
                    advance()
                }
                case .partnerInvite: PartnerInviteScreen(household: savedHousehold, partnerName: draft.partnerFirstName) { advance() }
                case .lifeSync: LifeSyncSetupScreen(draft: draft, household: savedHousehold) { advance() }
                case .premium: PremiumOfferScreen(draft: draft, household: savedHousehold) { finish() }
                }
            }
            .id(step)
            .transition(.opacity)
        }
        .animation(Motion.crossfade, value: step)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            if step == .intro {
                Color.clear.frame(height: 40)
            } else {
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
            // The intro doesn't count: the hook is 1 of 10.
            ProgressBar(progress: Double(step.rawValue) / Double(OnboardingStep.allCases.count - 1),
                        current: step.rawValue, total: OnboardingStep.allCases.count - 1)
            Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    private func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) { step = next } else { finish() }
    }

    private func back() {
        if let prev = OnboardingStep(rawValue: step.rawValue - 1), prev != .intro { step = prev }
    }

    /// The premium screen is the last step; a short dark "saved" moment plays before Home.
    private func finish() {
        appState.premiumOfferSeenInOnboarding = true
        Analytics.track(.onboardingCompleted)
        withAnimation(Motion.crossfade) { showSavedMoment = true }
    }

    private func completeOnboarding() {
        appState.selectedTab = .home
        appState.hasCompletedOnboarding = true
    }
}

/// Shared frame for every onboarding screen: eyebrow, hook copy top-left, content,
/// actions pinned to the bottom. Blocks fade up one after another.
struct OnboardingScreen<Content: View, Actions: View>: View {
    var eyebrow: String? = nil
    let hook: String
    var subline: String? = nil
    @ViewBuilder var content: () -> Content
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        if let eyebrow {
                            Eyebrow(text: eyebrow).reveal(0)
                        }
                        Text(hook)
                            .font(Typography.hook)
                            .lineSpacing(7)
                            .foregroundStyle(Theme.Colors.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .reveal(1)
                        if let subline {
                            Text(subline)
                                .font(Typography.body)
                                .lineSpacing(4)
                                .foregroundStyle(Theme.Colors.sandDeep)
                                .fixedSize(horizontal: false, vertical: true)
                                .reveal(2)
                        }
                    }
                    .padding(.top, Theme.Spacing.xl)
                    content()
                        .reveal(3)
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
            VStack(spacing: Theme.Spacing.sm) {
                actions()
            }
            .reveal(4)
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, Theme.Spacing.lg)
        }
    }
}

/// The moment after onboarding: ink ground, the wordmark springs in, a line of
/// copy, then Home. Seek Faith's "Welcome" screen, in Petite Home's voice.
struct SavedMomentScreen: View {
    let household: Household?
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var markScale: CGFloat = 0.6
    @State private var markOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var ringOpacity: Double = 0

    private var percent: Int {
        guard let household else { return 0 }
        return Completeness.report(file: household.familyFile, household: household).percent
    }

    var body: some View {
        MomentScreen {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()
                Text("PETITE HOME CO.")
                    .font(Typography.wordmark)
                    .kerning(Theme.Tracking.wordmark * 20)
                    .foregroundStyle(Theme.Colors.powderBlue)
                    .scaleEffect(markScale)
                    .opacity(markOpacity)
                VStack(spacing: Theme.Spacing.md) {
                    Text("Saved.")
                        .font(Typography.serif(40))
                        .foregroundStyle(Theme.Colors.cream)
                    Text("Your \(AppCopy.binderLower) is \(percent) percent there. The rest takes a minute at a time, and the app will remind you.")
                        .font(Typography.body)
                        .lineSpacing(5)
                        .foregroundStyle(Theme.Colors.cream.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)
                Spacer()
                Button("Go to Home") { onDone() }
                    .buttonStyle(.moment)
                    .opacity(ringOpacity)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .onAppear {
            if reduceMotion {
                markScale = 1; markOpacity = 1; textOpacity = 1; ringOpacity = 1
                return
            }
            withAnimation(Motion.entrance.delay(0.2)) { markScale = 1 }
            withAnimation(.easeIn(duration: 1.0).delay(0.2)) { markOpacity = 1 }
            withAnimation(.easeIn(duration: 1.0).delay(0.9)) { textOpacity = 1 }
            withAnimation(.easeIn(duration: 0.8).delay(1.7)) { ringOpacity = 1 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { onDone() }
        }
    }
}
