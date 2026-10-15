import AppIntents
import WidgetKit

/// Ticking a chore on the widget. Marks it done in the snapshot at once and
/// queues it for the app, which completes the real task next time it runs.
struct CompleteChoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete chore"
    static var description = IntentDescription("Marks a Petite Home chore as done.")

    @Parameter(title: "Chore")
    var id: String

    init() {}
    init(id: String) { self.id = id }

    func perform() async throws -> some IntentResult {
        ChoreSnapshotStore.markDone(id)
        WidgetCenter.shared.reloadTimelines(ofKind: ChoreSnapshotStore.widgetKind)
        return .result()
    }
}
