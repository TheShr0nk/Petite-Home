import Foundation
import SwiftData
import WidgetKit

/// Feeds the home-screen widget and takes its ticks back.
@MainActor
enum ChoreWidgetBridge {
    /// Writes the open chores to the App Group and asks the widget to redraw.
    static func publish(household: Household) {
        let open = (household.tasks ?? []).filter { !$0.isDone }
            .sorted { ($0.isOverdue ? 0 : 1, $0.nextDue) < ($1.isOverdue ? 0 : 1, $1.nextDue) }
        var snap = ChoreSnapshotStore.read()
        snap.updatedAt = Date()
        snap.householdName = household.displayName
        snap.items = open.prefix(8).map {
            ChoreSnapshotItem(id: $0.uuid.uuidString, title: $0.title, due: $0.nextDue, isOverdue: $0.isOverdue,
                              assignee: $0.assignedTo?.displayName, icon: $0.category.systemImage)
        }
        ChoreSnapshotStore.write(snap)
        WidgetCenter.shared.reloadTimelines(ofKind: ChoreSnapshotStore.widgetKind)
    }

    /// Chores ticked in the widget become real completions here.
    static func applyPendingCompletions(household: Household, context: ModelContext) {
        let pending = ChoreSnapshotStore.takePendingCompletions()
        guard !pending.isEmpty else { return }
        for task in household.tasks ?? [] where pending.contains(task.uuid.uuidString) && !task.isDone {
            task.complete()
        }
        try? context.save()
    }
}
