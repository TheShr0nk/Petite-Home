import SwiftUI
import SwiftData

/// Household tasks (premium). Free users see the template list, greyed, and
/// the paywall on tap.
struct TasksView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Bindable var household: Household
    /// True when shown as the Tasks segment of Life Sync, which owns the title and settings gear.
    var embedded: Bool = false
    @State private var editingTask: HouseholdTask?
    @State private var showNew = false

    private var tasks: [HouseholdTask] { (household.tasks ?? []).sorted { $0.nextDue < $1.nextDue } }
    private var templatesEnabled: Bool { tasks.contains { $0.isFromTemplate } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                if entitlements.isPremium {
                    premiumContent
                } else {
                    LockedPreview(onTap: { appState.showPaywall(.tasks) }) { templateList(greyed: true) }
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle(embedded ? "Life Sync" : "Tasks")
        .toolbar {
            if !embedded { SettingsToolbarItem() }
            if entitlements.isPremium {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNew = true } label: { Image(systemName: "plus").foregroundStyle(Theme.Colors.powderBlueDk) }.accessibilityLabel("New task")
                }
            }
        }
        .sheet(item: $editingTask, onDismiss: save) { task in TaskEditorSheet(task: task, household: household) }
        .sheet(isPresented: $showNew, onDismiss: save) { TaskEditorSheet(task: nil, household: household) }
    }

    @ViewBuilder private var premiumContent: some View {
        if tasks.isEmpty {
            Text("Add the things the house needs, and the app will ask at the right time.").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
        }
        if !templatesEnabled {
            templateList(greyed: false)
        }
        let overdue = tasks.filter { $0.isOverdue && !$0.isDone }
        let upcoming = tasks.filter { !$0.isOverdue && !$0.isDone }
        let done = tasks.filter(\.isDone)
        if !overdue.isEmpty { taskGroup("Overdue", overdue) }
        if !upcoming.isEmpty { taskGroup("Coming up", upcoming) }
        if !done.isEmpty { taskGroup("Done", done) }
    }

    private func taskGroup(_ title: String, _ items: [HouseholdTask]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: title)
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(items) { task in
                        TaskRow(task: task, onComplete: { complete(task) }, onTap: { editingTask = task })
                        if task.id != items.last?.id { SandDivider().padding(.leading, Theme.Spacing.lg + 36) }
                    }
                }
            }
        }
    }

    private func templateList(greyed: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "Start with the usual")
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(TaskTemplate.pack) { t in
                        HStack(spacing: Theme.Spacing.md) {
                            BrandIcon(systemName: t.category.systemImage)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(t.title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                Text(t.recurrence.label).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                            }
                        }
                    }
                    ForEach(household.kids) { child in
                        HStack(spacing: Theme.Spacing.md) {
                            BrandIcon(systemName: "heart.text.square")
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(child.displayName)'s well-child visit").font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                Text("Every year, around the birthday").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                            }
                        }
                    }
                    if !greyed {
                        Button("Turn these on") { enableTemplates() }.buttonStyle(.primary)
                    }
                }
            }
        }
    }

    private func enableTemplates() {
        for t in TaskTemplate.pack where !tasks.contains(where: { $0.templateKey == t.key }) {
            household.tasks?.append(t.makeTask(due: TaskTemplate.firstDue(for: t)))
        }
        for child in household.kids {
            let t = TaskTemplate.wellChild(for: child)
            guard !tasks.contains(where: { $0.templateKey == t.key }) else { continue }
            household.tasks?.append(t.makeTask(due: TaskTemplate.firstDue(for: t, child: child)))
        }
        save()
    }

    private func complete(_ task: HouseholdTask) {
        withAnimation { task.complete() }
        save()
    }

    private func save() {
        try? context.save()
        Task { _ = await NotificationService.shared.requestPermission() }
        ExpirationScheduler.sync(household: household, isPremium: entitlements.isPremium)
    }
}

struct TaskRow: View {
    let task: HouseholdTask
    let onComplete: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Button(action: onComplete) {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(task.isDone ? Theme.Colors.success : Theme.Colors.sand)
            }
            .buttonStyle(.plain)
            .disabled(task.isDone)
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(task.isDone ? "Done" : task.nextDue.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(task.isOverdue && !task.isDone ? Theme.Colors.danger : Theme.Colors.sandDeep)
                        if let who = task.assignedTo { Text("· \(who.displayName)").foregroundStyle(Theme.Colors.sandDeep) }
                        if !task.completions.isEmpty, !task.isDone { Text("· done \(task.completions.count)×").foregroundStyle(Theme.Colors.sandDeep) }
                    }
                    .font(Typography.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            BrandIcon(systemName: task.category.systemImage, size: 15)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
    }
}

struct TaskEditorSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let task: HouseholdTask?
    let household: Household

    @State private var title = ""
    @State private var notes = ""
    @State private var recurrence: Recurrence = .none
    @State private var customDays = 45
    @State private var nextDue = Date()
    @State private var category: TaskCategory = .home
    @State private var assigneeID: UUID?

    var body: some View {
        NavigationStack {
            EditorScroll(title: task == nil ? "New task" : "Task") {
                LabeledField(label: "What", text: $title, placeholder: "e.g. Clean the gutters", autocapitalization: .sentences)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Repeats").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach(Recurrence.presets, id: \.storageKey) { r in
                            Chip(label: r.label, isSelected: r.storageKey == recurrence.storageKey) { recurrence = r }
                        }
                        Chip(label: "Custom", isSelected: recurrence.storageKey == "custom") { recurrence = .custom(days: customDays) }
                    }
                    if recurrence.storageKey == "custom" {
                        Stepper("Every \(customDays) days", value: $customDays, in: 1...730, step: 1) { _ in recurrence = .custom(days: customDays) }
                            .font(Typography.body)
                    }
                }
                DatePicker("Next due", selection: $nextDue, displayedComponents: .date).font(Typography.body).tint(Theme.Colors.powderBlueDk)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Category").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach(TaskCategory.allCases) { c in Chip(label: c.label, systemImage: c.systemImage, isSelected: c == category) { category = c } }
                    }
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Who").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        Chip(label: "Either of us", isSelected: assigneeID == nil) { assigneeID = nil }
                        ForEach(household.adults) { adult in Chip(label: adult.displayName, isSelected: assigneeID == adult.id) { assigneeID = adult.id } }
                    }
                }
                LabeledTextEditor(label: "Notes", text: $notes, hint: "Filter size, where the shutoff is, who to call")
                if let task, !task.completions.isEmpty {
                    SectionHeader(title: "History")
                    ForEach(task.completions.sorted(by: >), id: \.self) { d in
                        Text(d.formatted(date: .long, time: .omitted)).font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                    }
                }
                Button("Save") { save() }.buttonStyle(.primary(enabled: !title.isEmpty)).disabled(title.isEmpty)
                if let task {
                    Button("Delete task", role: .destructive) { context.delete(task); try? context.save(); dismiss() }
                        .font(Typography.button).foregroundStyle(Theme.Colors.danger).frame(maxWidth: .infinity)
                }
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
        .onAppear {
            guard let task else { return }
            title = task.title; notes = task.notes; recurrence = task.recurrence
            if case .custom(let d) = task.recurrence { customDays = d }
            nextDue = task.nextDue; category = task.category; assigneeID = task.assignedTo?.id
        }
    }

    private func save() {
        let target = task ?? HouseholdTask(title: title, recurrence: recurrence, nextDue: nextDue, category: category)
        target.title = title; target.notes = notes; target.recurrence = recurrence
        target.nextDue = nextDue; target.category = category
        target.assignedTo = household.adults.first { $0.id == assigneeID }
        if task == nil { household.tasks?.append(target) }
        try? context.save()
        dismiss()
    }
}
