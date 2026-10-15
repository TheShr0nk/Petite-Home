import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Bindable var household: Household
    @State private var showExport = false
    @State private var sharePayload: SharePayload?
    @State private var shareError: String?
    @State private var showAddDocument = false

    var body: some View {
        let report = Completeness.report(file: household.familyFile, household: household)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                greeting.reveal(0, baseDelay: 0.05)
                if report.percent < 100 {
                    finishCard(report).reveal(1, baseDelay: 0.05)
                }
                if household.guardianUndecided, !report.isFilled(.designatedGuardian) {
                    guardianNudge
                }
                BrandDivider()
                familyChores.reveal(2, baseDelay: 0.05)
                BrandDivider()
                upcoming.reveal(3, baseDelay: 0.05)
                if let me = appState.currentAdult(in: household), !me.calendarSyncEnabled, household.adults.count > 1 {
                    lifeSyncNudge(partnerName: household.adults.first { $0.uuid != me.uuid }?.displayName ?? "your partner")
                }
                if !household.kids.isEmpty {
                    BrandDivider()
                    SectionHeader(title: "The kids")
                    KidsRow(household: household)
                }
                BrandDivider()
                SectionHeader(title: "Quick actions")
                VStack(spacing: Theme.Spacing.sm) {
                    Button { showAddDocument = true } label: { Label("Add a document", systemImage: "doc.badge.plus") }.buttonStyle(.outline)
                    Button { invitePartner() } label: { Label("Share with partner", systemImage: "person.2") }.buttonStyle(.outline)
                    Button { showExport = true } label: { Label("Export PDF", systemImage: "arrow.up.doc") }.buttonStyle(.outline)
                }
                if let shareError {
                    Text(shareError).font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                }
                BrandDivider()
                NavigationLink { PicksView() } label: {
                    Card(background: Theme.Colors.powderBlueMist) {
                        HStack(spacing: Theme.Spacing.md) {
                            BrandIcon(systemName: "sparkles", isActive: true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Petite Picks").font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                Text("What we use, what we skipped, and why.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { SettingsToolbarItem() }
        .navigationDestination(for: Child.self) { child in ChildProfileView(child: child) }
        .sheet(isPresented: $showExport) { ExportOptionsSheet(household: household) }
        .sheet(item: $sharePayload) { payload in CloudSharingSheet(share: payload.share, container: payload.container) }
        .sheet(isPresented: $showAddDocument) { AddDocumentSheet(household: household) }
    }

    /// Seek Faith opens each tab with a greeting and a one-line subtitle. Ours names the day.
    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
            Text(timeGreeting)
                .font(Typography.title)
                .foregroundStyle(Theme.Colors.ink)
        }
        .padding(.top, Theme.Spacing.sm)
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = appState.currentAdult(in: household)?.firstName ?? ""
        let who = name.isEmpty || name == "Me" ? "" : ", \(name)"
        switch hour {
        case 5..<12: return "Good morning\(who)."
        case 12..<17: return "Good afternoon\(who)."
        case 17..<22: return "Good evening\(who)."
        default: return "Still up\(who)?"
        }
    }

    private func finishCard(_ report: CompletenessReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .center, spacing: Theme.Spacing.lg) {
                    CompletenessRing(percent: report.percent, size: 72, lineWidth: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Finish your \(AppCopy.binder)").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                        Text("Each of these takes about a minute.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    }
                }
                SandDivider()
                ForEach(Array(report.nextToAdd.prefix(3))) { field in
                    EmptyStateRow(instruction: field.instruction, systemImage: field.section.systemImage) {
                        Task { _ = await NotificationService.shared.requestPermission() }
                        appState.open(field)
                    }
                    if field != report.nextToAdd.prefix(3).last { SandDivider() }
                }
            }
        }
    }

    private var guardianNudge: some View {
        Card(background: Theme.Colors.powderBlueMist) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("Still deciding who'd care for the kids?").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                Text("Most people pick someone imperfect and move on. You can change it any time.").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                Button("Name someone") { appState.open(.designatedGuardian) }.font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.accentText)
            }
        }
    }

    private func lifeSyncNudge(partnerName: String) -> some View {
        Card(background: Theme.Colors.powderBlueMist) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("See the week you and \(partnerName) actually have").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                Text("The \(AppCopy.planner) puts both calendars, the house tasks, meals and date nights on the same days.").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                if !entitlements.isPremium { PremiumPill() }
                Button("Sync my calendar") { if entitlements.isPremium { appState.selectedTab = .lifeSync } else { appState.showPaywall(.lifeSync) } }.font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.accentText)
            }
        }
    }

    private var todayEvents: [CalendarEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        return (household.calendarEvents ?? []).filter { $0.startDate < end && $0.endDate > start }.sorted { $0.startDate < $1.startDate }
    }

    private var nextPlan: FamilyPlan? {
        (household.plans ?? []).filter { !$0.isPast }.sorted { $0.startDate < $1.startDate }.first
    }

    private var tonight: PlannedMeal? {
        (household.meals ?? []).first { Calendar.current.isDateInToday($0.date) && $0.slot == .dinner }
    }

    /// The household's open chores, overdue first, checkable right here. Header and rows open the Tasks segment.
    private var familyChores: some View {
        let open = (household.tasks ?? []).filter { !$0.isDone }
            .sorted { ($0.isOverdue ? 0 : 1, $0.nextDue) < ($1.isOverdue ? 0 : 1, $1.nextDue) }
        let shown = Array(open.prefix(4))
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Button { appState.openTasks() } label: {
                HStack {
                    SectionHeader(title: "Family chores", detail: open.isEmpty ? nil : "\(open.count)")
                    Spacer()
                    Text("See all").font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.accentText)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Family chores, see all")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    if shown.isEmpty {
                        EmptyStateRow(instruction: "Add the first chore, or pick from the usual ones", systemImage: "checklist") { appState.openTasks() }
                            .padding(.horizontal, Theme.Spacing.lg)
                    }
                    ForEach(shown, id: \.uuid) { task in
                        TaskRow(task: task, onComplete: { completeChore(task) }, onTap: { appState.openTasks() })
                        if task.uuid != shown.last?.uuid { SandDivider().padding(.leading, Theme.Spacing.lg + 36) }
                    }
                    if open.count > shown.count {
                        SandDivider().padding(.leading, Theme.Spacing.lg)
                        Button { appState.openTasks() } label: {
                            HStack { Text("\(open.count - shown.count) more").font(Typography.caption).foregroundStyle(Theme.Colors.accentText); Spacer() }
                                .padding(.horizontal, Theme.Spacing.lg).padding(.vertical, Theme.Spacing.md).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func completeChore(_ task: HouseholdTask) {
        withAnimation { task.complete() }
        try? context.save()
        ExpirationScheduler.sync(household: household, isPremium: entitlements.isPremium)
        PhoneSyncService.shared.syncIfEnabled(household: household, context: context, isPremium: entitlements.isPremium)
        ChoreWidgetBridge.publish(household: household)
    }

    private var upcoming: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Upcoming")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    if entitlements.isPremium, let nextPlan, nextPlan.startDate < Calendar.current.date(byAdding: .day, value: 14, to: Date())! {
                        Button { appState.openPlans() } label: {
                            UpcomingRow(title: nextPlan.displayTitle, date: nextPlan.startDate, tone: nextPlan.needsAttention ? .warn : .normal, icon: nextPlan.kind.systemImage,
                                        subtitle: nextPlan.needsAttention ? "\(nextPlan.startDate.formatted(.dateTime.weekday(.abbreviated).day())) · still need a sitter" : nil)
                                .padding(.horizontal, Theme.Spacing.lg).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        SandDivider().padding(.leading, Theme.Spacing.lg)
                    }
                    if entitlements.isPremium, let tonight {
                        Button { appState.openMeals() } label: {
                            UpcomingRow(title: "Tonight: \(tonight.displayTitle)", date: Date(), tone: .normal, icon: "fork.knife",
                                        subtitle: household.adults.first { $0.uuid == tonight.cookAdultID }.map { "\($0.displayName) cooks" } ?? "Dinner")
                                .padding(.horizontal, Theme.Spacing.lg).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        SandDivider().padding(.leading, Theme.Spacing.lg)
                    }
                    ForEach(todayEvents.prefix(2), id: \.uuid) { event in
                        let who = household.adults.first { $0.uuid == event.ownerAdultID }?.displayName
                        UpcomingRow(title: who.map { "\(event.title) · \($0)" } ?? event.title,
                                    date: event.startDate, tone: .normal, icon: "calendar",
                                    subtitle: event.isAllDay ? "Today, all day" : "Today at \(event.startDate.formatted(date: .omitted, time: .shortened))")
                            .padding(.horizontal, Theme.Spacing.lg)
                        SandDivider().padding(.leading, Theme.Spacing.lg)
                    }
                    if entitlements.isPremium {
                        let exps = ExpirationScheduler.upcoming(for: household)
                        if exps.isEmpty && todayEvents.isEmpty && nextPlan == nil && tonight == nil {
                            EmptyStateRow(instruction: "Add a date that expires, like the car registration or a passport", systemImage: "calendar") { appState.open(.vehicles) }
                                .padding(.horizontal, Theme.Spacing.lg)
                        }
                        ForEach(exps) { exp in
                            UpcomingRow(title: exp.title, date: exp.date, tone: exp.isOverdue ? .danger : (exp.isSoon ? .warn : .normal), icon: "calendar.badge.exclamationmark")
                                .padding(.horizontal, Theme.Spacing.lg)
                            SandDivider().padding(.leading, Theme.Spacing.lg)
                        }
                    } else {
                        LockedPreview(gate: .expirationReminder, onTap: { appState.showPaywall(.expirationReminder) }, bannerFirst: false) {
                            VStack(spacing: 0) {
                                UpcomingRow(title: "Passport expires", date: Calendar.current.date(byAdding: .day, value: 45, to: Date())!, tone: .warn, icon: "calendar.badge.exclamationmark")
                                    .padding(.horizontal, Theme.Spacing.lg)
                                SandDivider().padding(.leading, Theme.Spacing.lg)
                                UpcomingRow(title: "Change the furnace filter", date: Calendar.current.date(byAdding: .day, value: 12, to: Date())!, tone: .normal, icon: "house")
                                    .padding(.horizontal, Theme.Spacing.lg)
                            }
                        }
                    }
                }
            }
        }
    }

    private func invitePartner() {
        Task {
            do {
                let (share, container) = try await CloudSharingService.shared.share(for: household.uuid, title: "Our \(AppCopy.binder)")
                sharePayload = SharePayload(share: share, container: container)
            } catch {
                shareError = error.localizedDescription
            }
        }
    }
}

struct UpcomingRow: View {
    enum Tone { case normal, warn, danger }
    let title: String
    let date: Date
    let tone: Tone
    let icon: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            BrandIcon(systemName: icon, isActive: tone != .normal)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                Text(subtitle ?? relative).font(Typography.caption).foregroundStyle(color)
            }
            Spacer()
        }
        .padding(.vertical, Theme.Spacing.md)
    }

    private var color: Color {
        switch tone {
        case .normal: return Theme.Colors.sandDeep
        case .warn: return Theme.Colors.warn
        case .danger: return Theme.Colors.danger
        }
    }

    private var relative: String {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0
        if days < 0 { return "\(-days) days overdue" }
        if days == 0 { return "Today" }
        if days == 1 { return "Tomorrow" }
        if days < 60 { return "In \(days) days" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
