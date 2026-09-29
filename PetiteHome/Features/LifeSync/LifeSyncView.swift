import SwiftUI
import SwiftData
import EventKit

/// The Planner (premium): the week the two of you actually have. Both calendars,
/// mirrored through the household, plus the tasks due each day. Free users
/// see a sample week, locked, and the paywall on tap.
struct LifeSyncView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Bindable var household: Household
    @State private var showSetup = false
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var editingTask: HouseholdTask?

    private var me: Adult? { appState.currentAdult(in: household) }
    private var partner: Adult? { household.adults.first { $0.uuid != me?.uuid } }

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            Picker("View", selection: $appState.lifeSyncSegment) {
                ForEach(LifeSyncSegment.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, Theme.Spacing.sm)
            if appState.lifeSyncSegment == .tasks {
                TasksView(household: household, embedded: true)
            } else if appState.lifeSyncSegment == .plans {
                PlansView(household: household)
            } else if appState.lifeSyncSegment == .meals {
                MealsView(household: household)
            } else if entitlements.isPremium {
                week
            } else {
                lockedWeek
            }
        }
        .screenBackground()
        .navigationTitle(AppCopy.planner)
        .toolbar { SettingsToolbarItem() }
        .sheet(isPresented: $showSetup, onDismiss: resync) { LifeSyncSetupSheet(household: household) }
        .sheet(item: $editingTask) { task in TaskEditorSheet(task: task, household: household) }
        .onAppear(perform: resync)
        .onChange(of: entitlements.isPremium) { _, _ in resync() }
        .onReceive(NotificationCenter.default.publisher(for: .calendarSourceChanged)) { _ in resync() }
    }

    // MARK: Free: a sample week, locked

    private var lockedWeek: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("Both calendars and the house tasks on the same days, so neither of you has to ask.")
                    .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                LockedPreview(onTap: { appState.showPaywall(.lifeSync) }) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        let days = LifeSyncAgenda.build(events: SampleWeek.events(me: me, partner: partner), tasks: [], from: Date(), days: 7)
                        dayStrip(days, interactive: false)
                        if let today = days.first {
                            SectionHeader(title: today.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            Card(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(SampleWeek.today(me: me, partner: partner)) { item in
                                        AgendaRow(item: item, me: me, partner: partner) { }
                                        SandDivider().padding(.leading, Theme.Spacing.lg + 44)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    // MARK: Premium

    private var week: some View {
        let days = LifeSyncAgenda.build(events: household.calendarEvents ?? [], tasks: household.tasks ?? [], meals: household.meals ?? [], plans: household.plans ?? [], from: Date(), days: 14)
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                statusCard
                dayStrip(days, interactive: true)
                if let day = days.first(where: { $0.date == selectedDay }) {
                    agenda(for: day)
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, Theme.Spacing.xl)
        }
    }

    private var statusCard: some View {
        Card(background: (me?.calendarSyncEnabled ?? false) ? Theme.Colors.creamDeep : Theme.Colors.powderBlueMist) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let me, me.calendarSyncEnabled {
                    HStack(spacing: Theme.Spacing.md) {
                        AvatarView(initial: me.displayName, kind: .adult, size: 32)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Your calendar is syncing").font(Typography.body).foregroundStyle(Theme.Colors.ink)
                            Text(me.calendarSyncedAt.map { "Updated \($0.formatted(.relative(presentation: .named)))" } ?? "Waiting for the first sync")
                                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        }
                        Spacer()
                        Button("Calendars") { showSetup = true }.font(Typography.caption).foregroundStyle(Theme.Colors.powderBlueDk)
                    }
                    if let partner {
                        SandDivider()
                        HStack(spacing: Theme.Spacing.md) {
                            AvatarView(initial: partner.displayName, kind: .adult, size: 32)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(partner.calendarSyncEnabled ? "\(partner.displayName)'s calendar is syncing" : "\(partner.displayName) hasn't turned this on yet")
                                    .font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                Text(partner.calendarSyncEnabled
                                     ? (partner.calendarSyncedAt.map { "Updated \($0.formatted(.relative(presentation: .named)))" } ?? "")
                                     : "Ask them to open the \(AppCopy.planner) on their phone and tap Sync my calendar.")
                                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                            }
                        }
                    }
                } else {
                    Text("See the week the two of you actually have.").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                    Text(partner.map { "Pick which calendars to share. \($0.displayName) sees when you're busy, you see when they are, and the house tasks sit on the same days." }
                         ?? "Pick which calendars to show here. When your partner joins the household, they'll see them too.")
                        .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                    Button("Sync my calendar") { showSetup = true }.buttonStyle(.primary)
                    Text("Read-only. Nothing is written to your calendar, and nothing leaves your family's iCloud.")
                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
            }
        }
    }

    private func dayStrip(_ days: [LifeSyncAgenda.Day], interactive: Bool) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(days) { day in
                    let selected = day.date == selectedDay
                    Button { if interactive { selectedDay = day.date } } label: {
                        VStack(spacing: 4) {
                            Text(day.date.formatted(.dateTime.weekday(.abbreviated))).font(Typography.capsLabel).textCase(.uppercase)
                                .foregroundStyle(selected ? Theme.Colors.ink : Theme.Colors.sandDeep)
                            Text(day.date.formatted(.dateTime.day())).font(Typography.serif(20)).foregroundStyle(Theme.Colors.ink)
                            HStack(spacing: 3) {
                                ForEach(Array(dots(for: day).enumerated()), id: \.offset) { _, color in Circle().fill(color).frame(width: 5, height: 5) }
                            }
                            .frame(height: 6)
                        }
                        .frame(width: 48, height: 68)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(selected ? Theme.Colors.powderBlue : Theme.Colors.creamDeep))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Up to three dots: mine, theirs, tasks.
    private func dots(for day: LifeSyncAgenda.Day) -> [Color] {
        var out: [Color] = []
        if day.items.contains(where: { $0.kind == .event && $0.ownerAdultID == me?.uuid }) { out.append(Theme.Colors.powderBlueDk) }
        if day.items.contains(where: { $0.kind == .event && $0.ownerAdultID != me?.uuid }) { out.append(Theme.Colors.sand) }
        if day.items.contains(where: { $0.kind == .task || $0.kind == .meal || $0.kind == .plan }) { out.append(Theme.Colors.success) }
        return out
    }

    private func agenda(for day: LifeSyncAgenda.Day) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()),
                          detail: day.items.isEmpty ? nil : "\(day.items.count) \(day.items.count == 1 ? "thing" : "things")")
            if day.items.isEmpty {
                Card {
                    Text(me?.calendarSyncEnabled == true ? "Nothing on either calendar. A good day for the furnace filter." : "Turn on calendar sync to see what's on.")
                        .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                }
            } else {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(day.items) { item in
                            AgendaRow(item: item, me: me, partner: partner) {
                                if item.kind == .task, let task = (household.tasks ?? []).first(where: { $0.uuid == item.id }) { editingTask = task }
                                if item.kind == .meal { appState.openMeals() }
                                if item.kind == .plan { appState.openPlans() }
                            }
                            if item.id != day.items.last?.id { SandDivider().padding(.leading, Theme.Spacing.lg + 44) }
                        }
                    }
                }
            }
        }
    }

    private func resync() {
        guard entitlements.isPremium, let me else { return }
        LifeSyncPending.apply(to: household, adult: me, context: context)
        CalendarSyncService.shared.sync(adult: me, household: household, context: context)
    }
}

/// Placeholder rows for the locked preview. Never saved.
enum SampleWeek {
    static func events(me: Adult?, partner: Adult?) -> [CalendarEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func ev(_ title: String, day: Int, hour: Int, who: UUID?) -> CalendarEvent {
            let start = cal.date(byAdding: .hour, value: hour, to: cal.date(byAdding: .day, value: day, to: today)!)!
            return CalendarEvent(sourceIdentifier: title, title: title, startDate: start, endDate: start.addingTimeInterval(3600), isAllDay: false, calendarName: "Home", ownerAdultID: who)
        }
        return [ev("Daycare pickup", day: 0, hour: 16, who: partner?.uuid), ev("Dentist", day: 1, hour: 14, who: me?.uuid), ev("Standup", day: 2, hour: 9, who: me?.uuid), ev("Date night", day: 4, hour: 19, who: partner?.uuid)]
    }
    static func today(me: Adult?, partner: Adult?) -> [AgendaItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return [
            AgendaItem(id: UUID(), kind: .task, title: "Check car seat straps and fit", start: today, end: nil, isAllDay: true, ownerAdultID: nil, detail: "Every month", isOverdue: false),
            AgendaItem(id: UUID(), kind: .event, title: "Standup", start: cal.date(byAdding: .hour, value: 9, to: today)!, end: cal.date(byAdding: .hour, value: 10, to: today)!, isAllDay: false, ownerAdultID: me?.uuid, detail: "Work", isOverdue: false),
            AgendaItem(id: UUID(), kind: .event, title: "Daycare pickup", start: cal.date(byAdding: .hour, value: 16, to: today)!, end: cal.date(byAdding: .hour, value: 17, to: today)!, isAllDay: false, ownerAdultID: partner?.uuid, detail: "Family", isOverdue: false),
            AgendaItem(id: UUID(), kind: .meal, title: "Sheet-pan chicken", start: cal.date(byAdding: .hour, value: 18, to: today)!, end: nil, isAllDay: false, ownerAdultID: me?.uuid, detail: "Dinner", isOverdue: false),
            AgendaItem(id: UUID(), kind: .plan, title: "Date night", start: cal.date(byAdding: .hour, value: 19, to: today)!, end: nil, isAllDay: false, ownerAdultID: nil, detail: "Date night · confirmed", isOverdue: false),
        ]
    }
}

struct AgendaRow: View {
    let item: AgendaItem
    let me: Adult?
    let partner: Adult?
    let onTap: () -> Void

    private var owner: Adult? { [me, partner].compactMap { $0 }.first { $0.uuid == item.ownerAdultID } }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                if item.kind != .event {
                    ZStack {
                        Circle().fill((item.kind == .meal ? Theme.Colors.warn : item.kind == .plan ? Theme.Colors.powderBlue : Theme.Colors.success).opacity(item.kind == .plan ? 0.5 : 0.25))
                        Image(systemName: item.kind == .meal ? "fork.knife" : item.kind == .plan ? "moon.stars" : "checklist").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.ink)
                    }
                    .frame(width: 32, height: 32)
                } else {
                    AvatarView(initial: owner?.displayName ?? "?", kind: .adult, size: 32)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(Typography.body).foregroundStyle(Theme.Colors.ink).lineLimit(2)
                    HStack(spacing: Theme.Spacing.xs) {
                        if item.kind == .event {
                            Text(item.isAllDay ? "All day" : timeRange)
                            if !item.detail.isEmpty { Text("· \(item.detail)") }
                            if let owner, owner.uuid != me?.uuid { Text("· \(owner.displayName)") }
                        } else if item.kind == .meal {
                            Text(item.detail)
                            if let owner { Text("· \(owner.displayName) cooks") }
                        } else if item.kind == .plan {
                            Text(item.start.formatted(date: .omitted, time: .shortened)).foregroundStyle(Theme.Colors.sandDeep)
                            Text("· \(item.detail)").foregroundStyle(item.isOverdue ? Theme.Colors.warn : Theme.Colors.sandDeep)
                        } else {
                            Text(item.isOverdue ? "Overdue" : "Due today").foregroundStyle(item.isOverdue ? Theme.Colors.danger : Theme.Colors.sandDeep)
                            if let owner { Text("· \(owner.displayName)") }
                        }
                    }
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                Spacer()
                if item.kind != .event { Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep) }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.kind == .event)
    }

    private var timeRange: String {
        let f = Date.FormatStyle.dateTime.hour().minute()
        if let end = item.end { return "\(item.start.formatted(f)) – \(end.formatted(f))" }
        return item.start.formatted(f)
    }
}

/// Calendar access and which calendars to mirror. Shared by onboarding and the Life Sync tab.
struct CalendarPickerBlock: View {
    @Binding var granted: Bool
    @Binding var selected: Set<String>
    @State private var denied = false
    @State private var calendars: [EKCalendar] = []

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if !granted {
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Allow access to your calendars").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                        Text("The app reads the calendars you pick and shows them to your partner. It never adds or changes events.")
                            .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                        if denied {
                            Button("Turn on in Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }.buttonStyle(.outline)
                        } else {
                            Button("Allow") {
                                Task {
                                    granted = await CalendarSyncService.shared.requestAccess()
                                    denied = !granted
                                    if granted { load() }
                                }
                            }.buttonStyle(.primary)
                        }
                    }
                }
            } else {
                Text("Which calendars to share").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(calendars, id: \.calendarIdentifier) { cal in
                            Toggle(isOn: Binding(get: { selected.contains(cal.calendarIdentifier) }, set: { on in if on { selected.insert(cal.calendarIdentifier) } else { selected.remove(cal.calendarIdentifier) } })) {
                                HStack(spacing: Theme.Spacing.md) {
                                    Circle().fill(Color(cgColor: cal.cgColor)).frame(width: 10, height: 10)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(cal.title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                        Text(cal.source.title).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                                    }
                                }
                            }
                            .tint(Theme.Colors.powderBlueDk)
                            .padding(.horizontal, Theme.Spacing.lg).padding(.vertical, Theme.Spacing.md)
                            if cal.calendarIdentifier != calendars.last?.calendarIdentifier { SandDivider().padding(.leading, Theme.Spacing.lg) }
                        }
                    }
                }
                Text("Skip work calendars you'd rather keep to yourself. Only titles and times are shared.")
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            }
        }
        .onAppear { if granted { load() } }
    }

    private func load() {
        calendars = CalendarSyncService.shared.calendars()
        // First time through, preselect everything that isn't obviously work or a subscription.
        if selected.isEmpty {
            selected = Set(calendars.filter { $0.type != .subscription && $0.type != .birthday && !$0.title.lowercased().contains("work") }.map(\.calendarIdentifier))
        }
    }
}

/// Which phone is whose, then the calendar picker. Premium only.
struct LifeSyncSetupSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var household: Household
    @State private var granted = CalendarSyncService.shared.hasAccess
    @State private var selected = CalendarSyncService.shared.selectedCalendarIDs

    var body: some View {
        NavigationStack {
            EditorScroll(title: "Sync my calendar") {
                if household.adults.count > 1 {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("This phone belongs to").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                        HStack {
                            ForEach(household.adults, id: \.uuid) { adult in
                                Chip(label: adult.displayName, isSelected: appState.currentAdult(in: household)?.uuid == adult.uuid) { appState.currentAdultID = adult.uuid }
                            }
                        }
                    }
                }
                CalendarPickerBlock(granted: $granted, selected: $selected)
                if granted {
                    Button("Start syncing") { enable() }.buttonStyle(.primary(enabled: !selected.isEmpty)).disabled(selected.isEmpty)
                }
                if appState.currentAdult(in: household)?.calendarSyncEnabled == true {
                    Button("Stop syncing my calendar", role: .destructive) { disable() }
                        .font(Typography.button).foregroundStyle(Theme.Colors.danger).frame(maxWidth: .infinity)
                }
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
    }

    private func enable() {
        guard let me = appState.currentAdult(in: household) else { return }
        CalendarSyncService.shared.selectedCalendarIDs = selected
        let wasOn = me.calendarSyncEnabled
        me.calendarSyncEnabled = true
        CalendarSyncService.shared.sync(adult: me, household: household, context: context)
        if !wasOn { Analytics.track(.lifeSyncEnabled, ["calendars": selected.count, "from": "tab"]) }
        dismiss()
    }

    private func disable() {
        guard let me = appState.currentAdult(in: household) else { return }
        CalendarSyncService.shared.disable(adult: me, household: household, context: context)
        dismiss()
    }
}
