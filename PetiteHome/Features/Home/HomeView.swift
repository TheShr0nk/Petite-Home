import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Bindable var household: Household
    @State private var showExport = false
    @State private var sharePayload: SharePayload?
    @State private var shareError: String?
    @State private var showAddDocument = false

    var body: some View {
        let report = Completeness.report(file: household.familyFile, household: household)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if report.percent < 100 {
                    finishCard(report)
                }
                if household.guardianUndecided, !report.isFilled(.designatedGuardian) {
                    guardianNudge
                }
                upcoming
                if !household.kids.isEmpty {
                    SectionHeader(title: "The kids")
                    KidsRow(household: household)
                }
                SectionHeader(title: "Quick actions")
                VStack(spacing: Theme.Spacing.sm) {
                    Button { showAddDocument = true } label: { Label("Add a document", systemImage: "doc.badge.plus") }.buttonStyle(.outline)
                    Button { invitePartner() } label: { Label("Share with partner", systemImage: "person.2") }.buttonStyle(.outline)
                    Button { showExport = true } label: { Label("Export PDF", systemImage: "arrow.up.doc") }.buttonStyle(.outline)
                }
                if let shareError {
                    Text(shareError).font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Home")
        .toolbar { SettingsToolbarItem() }
        .navigationDestination(for: Child.self) { child in ChildProfileView(child: child) }
        .sheet(isPresented: $showExport) { ExportOptionsSheet(household: household) }
        .sheet(item: $sharePayload) { payload in CloudSharingSheet(share: payload.share, container: payload.container) }
        .sheet(isPresented: $showAddDocument) { AddDocumentSheet(household: household) }
    }

    private func finishCard(_ report: CompletenessReport) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(alignment: .center, spacing: Theme.Spacing.lg) {
                    CompletenessRing(percent: report.percent, size: 72, lineWidth: 7)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Finish your Family File").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
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
                Button("Name someone") { appState.open(.designatedGuardian) }.font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.powderBlueDk)
            }
        }
    }

    private var upcoming: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Upcoming")
            Card(padding: 0) {
                VStack(spacing: 0) {
                    if entitlements.isPremium {
                        let exps = ExpirationScheduler.upcoming(for: household)
                        let tasks = (household.tasks ?? []).filter { !$0.isDone }.sorted { $0.nextDue < $1.nextDue }.prefix(3)
                        if exps.isEmpty && tasks.isEmpty {
                            EmptyStateRow(instruction: "Add a date that expires, or turn on the task templates", systemImage: "calendar") { appState.selectedTab = .tasks }
                                .padding(.horizontal, Theme.Spacing.lg)
                        }
                        ForEach(exps) { exp in
                            UpcomingRow(title: exp.title, date: exp.date, tone: exp.isOverdue ? .danger : (exp.isSoon ? .warn : .normal), icon: "calendar.badge.exclamationmark")
                                .padding(.horizontal, Theme.Spacing.lg)
                            SandDivider().padding(.leading, Theme.Spacing.lg)
                        }
                        ForEach(Array(tasks)) { task in
                            UpcomingRow(title: task.title, date: task.nextDue, tone: task.isOverdue ? .danger : .normal, icon: task.category.systemImage)
                                .padding(.horizontal, Theme.Spacing.lg)
                            SandDivider().padding(.leading, Theme.Spacing.lg)
                        }
                    } else {
                        LockedPreview(onTap: { appState.showPaywall(.expirationReminder) }) {
                            UpcomingRow(title: "Passport expires", date: Calendar.current.date(byAdding: .day, value: 45, to: Date())!, tone: .warn, icon: "calendar.badge.exclamationmark")
                                .padding(.horizontal, Theme.Spacing.lg)
                        }
                        SandDivider().padding(.leading, Theme.Spacing.lg)
                        LockedPreview(onTap: { appState.showPaywall(.tasks) }) {
                            UpcomingRow(title: "Change the furnace filter", date: Calendar.current.date(byAdding: .day, value: 12, to: Date())!, tone: .normal, icon: "house")
                                .padding(.horizontal, Theme.Spacing.lg)
                        }
                    }
                }
            }
        }
    }

    private func invitePartner() {
        Task {
            do {
                let (share, container) = try await CloudSharingService.shared.share(for: household.id, title: "Our Family File")
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

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            BrandIcon(systemName: icon, isActive: tone != .normal)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                Text(relative).font(Typography.caption).foregroundStyle(color)
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
