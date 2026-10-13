import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case hook, household, firstContact, pediatrician, insurance, guardian, reveal, partnerInvite, lifeSync, premium

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
        case .lifeSync: return "life_sync"
        case .premium: return "premium"
        }
    }
}

/// Every screen does one thing. Progress bar at top, back button everywhere.
/// The app opens straight on the hook, no intro carousel: the value is shown by
/// doing, and the first real entry is two taps away. Everything after the hook can be skipped.
struct OnboardingFlow: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @State private var draft = OnboardingDraft()
    @State private var step: OnboardingStep = .hook
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
            Button {
                back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.sandDeep)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            .opacity(step == .hook || step.rawValue > OnboardingStep.reveal.rawValue ? 0 : 1)
            .disabled(step == .hook || step.rawValue > OnboardingStep.reveal.rawValue)
            ProgressBar(progress: Double(step.rawValue + 1) / Double(OnboardingStep.allCases.count),
                        current: step.rawValue + 1, total: OnboardingStep.allCases.count)
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    private func advance() {
        if let next = OnboardingStep(rawValue: step.rawValue + 1) { step = next } else { finish() }
    }

    private func back() {
        if let prev = OnboardingStep(rawValue: step.rawValue - 1) { step = prev }
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
            .glassScrollEdge(.bottom)
            // The action bar floats over the content: glass buttons on iOS 26,
            // a cream bar before that.
            .safeAreaInset(edge: .bottom) {
                GlassGroup {
                    VStack(spacing: Theme.Spacing.sm) {
                        actions()
                    }
                }
                .reveal(4)
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.lg)
                .background(Glass26.available ? Color.clear : Theme.Colors.cream)
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
    /// True when the system has never been asked: the moment then offers reminders instead of timing out.
    @State private var askNotifications = false

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
                    .foregroundStyle(Theme.Colors.Fixed.powderBlue)
                    .scaleEffect(markScale)
                    .opacity(markOpacity)
                VStack(spacing: Theme.Spacing.md) {
                    Text("Saved.")
                        .font(Typography.serif(40))
                        .foregroundStyle(Theme.Colors.Fixed.cream)
                    Text("Your \(AppCopy.binderLower) is \(percent) percent there. The rest comes a minute at a time, and we'll nudge you when it's time.")
                        .font(Typography.body)
                        .lineSpacing(5)
                        .foregroundStyle(Theme.Colors.Fixed.cream.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)
                Spacer()
                VStack(spacing: Theme.Spacing.md) {
                    if askNotifications {
                        Text("We can nudge you when something expires or a chore comes due. Nothing else.")
                            .font(Typography.caption)
                            .foregroundStyle(Theme.Colors.Fixed.cream.opacity(0.7))
                            .multilineTextAlignment(.center)
                        Button("Turn on reminders") {
                            Task { _ = await NotificationService.shared.requestPermission(); onDone() }
                        }
                        .buttonStyle(.moment)
                        Button { onDone() } label: {
                            Text("Not now").font(Typography.body).foregroundStyle(Theme.Colors.Fixed.cream.opacity(0.7))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button("Go to Home") { onDone() }
                            .buttonStyle(.moment)
                    }
                }
                .opacity(ringOpacity)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .task {
            askNotifications = await NotificationService.shared.authorizationStatus() == .notDetermined
            if reduceMotion {
                markScale = 1; markOpacity = 1; textOpacity = 1; ringOpacity = 1
            } else {
                withAnimation(Motion.entrance.delay(0.2)) { markScale = 1 }
                withAnimation(.easeIn(duration: 1.0).delay(0.2)) { markOpacity = 1 }
                withAnimation(.easeIn(duration: 1.0).delay(0.9)) { textOpacity = 1 }
                withAnimation(.easeIn(duration: 0.8).delay(1.7)) { ringOpacity = 1 }
            }
            // With the reminders question on screen the moment waits for an answer.
            if !askNotifications {
                try? await Task.sleep(for: .seconds(reduceMotion ? 2.5 : 4.0))
                onDone()
            }
        }
    }
}
