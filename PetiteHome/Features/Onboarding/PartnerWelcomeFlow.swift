import SwiftUI
import SwiftData

/// The partner's first open after accepting the invite. Three short screens and
/// nothing to re-enter: which adult they are, their own calendar and phone
/// export, and reminders. Runs instead of onboarding when the household arrived
/// through someone else's share.
struct PartnerWelcomeFlow: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    let household: Household

    private enum Step: Int, CaseIterable { case who, calendar, reminders }
    @State private var step: Step = .who
    @State private var chosenAdultID: UUID?
    @State private var calendarGranted = CalendarSyncService.shared.hasAccess
    @State private var selectedCalendarIDs: Set<String> = []
    @State private var calendarSkipped = false
    @State private var remindersExport = false
    @State private var calendarExport = false
    @State private var askNotifications = true

    private var ownerName: String {
        let name = household.owner?.firstName ?? ""
        return name.isEmpty ? "Your partner" : name
    }
    private var me: Adult? { household.adults.first { $0.uuid == chosenAdultID } }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                Group {
                    switch step {
                    case .who: whoScreen
                    case .calendar: calendarScreen
                    case .reminders: remindersScreen
                    }
                }
                .id(step)
                .transition(.opacity)
            }
            .animation(Motion.crossfade, value: step)
        }
        .screenBackground()
        .onAppear {
            if chosenAdultID == nil { chosenAdultID = (household.partner ?? household.adults.first)?.uuid }
            Analytics.track(.onboardingStepViewed, ["step": "partner_welcome"])
        }
        .task { askNotifications = await NotificationService.shared.authorizationStatus() == .notDetermined }
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button { back() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.Colors.sandDeep)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Back")
            .opacity(step == .who ? 0 : 1)
            .disabled(step == .who)
            ProgressBar(progress: Double(step.rawValue + 1) / Double(Step.allCases.count),
                        current: step.rawValue + 1, total: Step.allCases.count)
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.top, Theme.Spacing.sm)
    }

    // MARK: Screens

    private var whoScreen: some View {
        OnboardingScreen(eyebrow: "You're in", hook: "\(ownerName) shared the \(AppCopy.binderLower) with you.",
                         subline: "Everything's already here. Pick your name so the \(AppCopy.planner) knows whose calendar is whose.") {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Which one are you?").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    ForEach(household.adults, id: \.uuid) { adult in
                        SelectableRow(title: adult.displayName, detail: adult.isAccountOwner ? "Set this up" : nil,
                                      systemImage: "person", isSelected: chosenAdultID == adult.uuid) { chosenAdultID = adult.uuid }
                    }
                }
                if !kidsLine.isEmpty {
                    Text(kidsLine).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
            }
        } actions: {
            Button("That's me") { advance() }.buttonStyle(.primary)
        }
    }

    private var kidsLine: String {
        let names = household.kids.map(\.firstName).filter { !$0.isEmpty }
        return names.isEmpty ? "" : "Kids: " + names.joined(separator: ", ") + "."
    }

    private var calendarScreen: some View {
        OnboardingScreen(eyebrow: AppCopy.planner, hook: "Now your calendar.",
                         subline: "Pick which calendars \(ownerName) can see. The chores are already shared, so you'll find them on the \(AppCopy.planner).") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                CalendarPickerBlock(granted: $calendarGranted, selected: $selectedCalendarIDs)
                PhoneExportRows(reminders: $remindersExport, calendar: $calendarExport)
                if !entitlements.isPremium {
                    Text("\(ownerName)'s subscription covers you when Apple Family Sharing is on. If the \(AppCopy.planner) asks you to subscribe, turn that on first, then tap Restore purchases.")
                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
            }
        } actions: {
            Button("Continue") { calendarSkipped = false; advance() }.buttonStyle(.primary)
            Button("I'll do this later") { calendarSkipped = true; advance() }.buttonStyle(.secondary)
        }
    }

    private var remindersScreen: some View {
        OnboardingScreen(eyebrow: "Reminders", hook: "Want a nudge now and then?",
                         subline: "We'll tell you when something expires or a chore comes due. Nothing else.") {
            EmptyView()
        } actions: {
            Button("Turn on reminders") {
                Task { _ = await NotificationService.shared.requestPermission(); finish() }
            }
            .buttonStyle(.primary)
            Button("Not now") { finish() }.buttonStyle(.secondary)
        }
    }

    // MARK: Flow

    private func advance() {
        switch step {
        case .who: step = .calendar
        case .calendar: if askNotifications { step = .reminders } else { finish() }
        case .reminders: finish()
        }
    }

    private func back() {
        if let prev = Step(rawValue: step.rawValue - 1) { step = prev }
    }

    /// Applies what the partner chose. Without premium the calendar and export
    /// choices wait, like the owner's, until the Planner unlocks.
    private func finish() {
        if let me { appState.currentAdultID = me.uuid }
        let ids = calendarGranted && !calendarSkipped ? selectedCalendarIDs : []
        if entitlements.isPremium {
            if let me, !ids.isEmpty {
                CalendarSyncService.shared.selectedCalendarIDs = ids
                me.calendarSyncEnabled = true
                CalendarSyncService.shared.sync(adult: me, household: household, context: context)
                Analytics.track(.lifeSyncEnabled, ["calendars": ids.count, "from": "partner_welcome"])
            }
            let phone = PhoneSyncService.shared
            if remindersExport, phone.hasRemindersAccess { phone.tasksToReminders = true }
            if calendarExport, phone.hasCalendarAccess { phone.plansToCalendar = true }
            phone.syncIfEnabled(household: household, context: context, isPremium: true)
            try? context.save()
        } else if !calendarSkipped {
            LifeSyncPending.save(calendarIDs: ids, templateKeys: [], wellChild: false,
                                 remindersExport: remindersExport, calendarExport: calendarExport)
        }
        Analytics.track(.partnerJoined)
        appState.selectedTab = .home
        withAnimation(Motion.crossfade) { appState.partnerWelcomePending = false }
    }
}

/// The loading state between tapping a partner's invite and the household
/// landing from iCloud. Says what is happening, what to do if it stalls, and
/// always offers a way out.
struct SharedHouseholdSyncScreen: View {
    var error: String?
    let onGiveUp: () -> Void
    @State private var slow = false

    var body: some View {
        OnboardingScreen(eyebrow: "Your partner's invite",
                         hook: error == nil ? "Getting the \(AppCopy.binderLower) from your partner's phone." : "That invite didn't open.",
                         subline: error ?? (slow ? "This is taking longer than usual. Check that iCloud is on for Petite Home in Settings, and that your partner's phone is online."
                                                 : "A few seconds on a good connection. Nothing to do yet.")) {
            if error == nil {
                HStack { Spacer(); PulsingDots(); Spacer() }.padding(.top, Theme.Spacing.xl)
            }
        } actions: {
            if error == nil && !slow {
                Text("Waiting on iCloud").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            } else {
                if error == nil {
                    Button("Keep waiting") { slow = false; arm() }.buttonStyle(.primary)
                }
                Button("Set up my own instead") { onGiveUp() }.buttonStyle(error == nil ? .secondary : .secondary)
            }
        }
        .onAppear(perform: arm)
    }

    private func arm() {
        Task {
            try? await Task.sleep(for: .seconds(20))
            if !Task.isCancelled { slow = true }
        }
    }
}
