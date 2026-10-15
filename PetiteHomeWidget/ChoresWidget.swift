import WidgetKit
import SwiftUI

struct ChoresEntry: TimelineEntry {
    let date: Date
    let items: [ChoreSnapshotItem]
    let openCount: Int
    let householdName: String
}

struct ChoresProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChoresEntry {
        ChoresEntry(date: Date(), items: [
            ChoreSnapshotItem(id: "1", title: "Plan dinner", due: Date(), isOverdue: false, assignee: nil, icon: "fork.knife"),
            ChoreSnapshotItem(id: "2", title: "Check car seat straps", due: Date(), isOverdue: true, assignee: "Sam", icon: "car"),
        ], openCount: 2, householdName: "The Family")
    }
    func getSnapshot(in context: Context, completion: @escaping (ChoresEntry) -> Void) { completion(load()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ChoresEntry>) -> Void) {
        let entry = load()
        // Redraw at midnight so "today" and overdue stay honest; the app reloads on every change anyway.
        let midnight = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }
    private func load() -> ChoresEntry {
        let snap = ChoreSnapshotStore.read()
        let open = snap.items.filter { !$0.isDone }
        return ChoresEntry(date: Date(), items: Array(open.prefix(4)), openCount: open.count, householdName: snap.householdName)
    }
}

struct ChoresWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: ChoresEntry

    private var ink: Color { scheme == .dark ? ChorePalette.inkDark : ChorePalette.ink }
    private var muted: Color { scheme == .dark ? ChorePalette.mutedDark : ChorePalette.muted }
    private var accent: Color { scheme == .dark ? ChorePalette.accentDark : ChorePalette.accent }
    private var rows: Int { family == .systemSmall ? 3 : 4 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Family chores").font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
                Spacer()
                if entry.openCount > 0 {
                    Text("\(entry.openCount)").font(.system(size: 12, weight: .semibold)).foregroundStyle(accent)
                        .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(ChorePalette.blue.opacity(scheme == .dark ? 0.25 : 0.6)))
                }
            }
            if entry.items.isEmpty {
                Spacer()
                Text("Nothing on the list.").font(.system(size: 13)).foregroundStyle(muted)
                Text("Add one in the app.").font(.system(size: 11)).foregroundStyle(muted)
                Spacer()
            } else {
                ForEach(entry.items.prefix(rows)) { item in
                    HStack(spacing: 8) {
                        Button(intent: CompleteChoreIntent(id: item.id)) {
                            Image(systemName: "circle").font(.system(size: 16, weight: .regular)).foregroundStyle(item.isOverdue ? ChorePalette.danger : accent)
                        }
                        .buttonStyle(.plain)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title).font(.system(size: 13, weight: .medium)).foregroundStyle(ink).lineLimit(1)
                            if family != .systemSmall {
                                Text(detail(item)).font(.system(size: 11)).foregroundStyle(item.isOverdue ? ChorePalette.danger : muted).lineLimit(1)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
                if entry.openCount > rows {
                    Text("\(entry.openCount - rows) more in the app").font(.system(size: 11)).foregroundStyle(muted)
                }
                Spacer(minLength: 0)
            }
        }
        .widgetURL(URL(string: "petitehome://tasks"))
        .containerBackground(for: .widget) { scheme == .dark ? ChorePalette.creamDark : ChorePalette.cream }
    }

    private func detail(_ item: ChoreSnapshotItem) -> String {
        let when = item.isOverdue ? "Overdue" : (Calendar.current.isDateInToday(item.due) ? "Today" : item.due.formatted(.dateTime.weekday(.abbreviated).day()))
        if let who = item.assignee { return "\(when) · \(who)" }
        return when
    }
}

struct ChoresWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: ChoreSnapshotStore.widgetKind, provider: ChoresProvider()) { entry in
            ChoresWidgetView(entry: entry)
        }
        .configurationDisplayName("Family chores")
        .description("What the house needs today. Tick one off right here.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
