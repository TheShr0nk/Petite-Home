import Foundation
import SwiftUI

/// The chores the home-screen widget shows, written by the app into the App
/// Group container and read by the widget. The widget can mark one done; the
/// app applies that on its next launch or foreground. Compiled into both targets.
struct ChoreSnapshotItem: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var due: Date
    var isOverdue: Bool
    var assignee: String?
    var icon: String
    var isDone: Bool = false
}

struct ChoreSnapshot: Codable {
    var updatedAt: Date = Date()
    var householdName: String = ""
    var items: [ChoreSnapshotItem] = []
    var pendingCompletions: [String] = []
}

enum ChoreSnapshotStore {
    static let appGroup = "group.co.petitehome.app"
    static let widgetKind = "FamilyChores"

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appending(path: "chores.json")
    }

    static func read() -> ChoreSnapshot {
        guard let url, let data = try? Data(contentsOf: url), let snap = try? JSONDecoder().decode(ChoreSnapshot.self, from: data) else { return ChoreSnapshot() }
        return snap
    }

    static func write(_ snapshot: ChoreSnapshot) {
        guard let url, let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Widget side: tick a chore. Shown as done at once; the app makes it real next time it runs.
    static func markDone(_ id: String) {
        var snap = read()
        if let i = snap.items.firstIndex(where: { $0.id == id }) { snap.items[i].isDone = true }
        if !snap.pendingCompletions.contains(id) { snap.pendingCompletions.append(id) }
        write(snap)
    }

    /// App side: the ticks made in the widget since last time, cleared on read.
    static func takePendingCompletions() -> [String] {
        var snap = read()
        let pending = snap.pendingCompletions
        snap.pendingCompletions = []
        write(snap)
        return pending
    }
}

/// The few brand colors the widget needs, without the app's theme file.
enum ChorePalette {
    static let cream = Color(red: 0xFC / 255, green: 0xF8 / 255, blue: 0xF2 / 255)
    static let creamDark = Color(red: 0x17 / 255, green: 0x13 / 255, blue: 0x11 / 255)
    static let ink = Color(red: 0x2F / 255, green: 0x2A / 255, blue: 0x26 / 255)
    static let inkDark = Color(red: 0xF3 / 255, green: 0xEC / 255, blue: 0xE2 / 255)
    static let muted = Color(red: 0x7E / 255, green: 0x6A / 255, blue: 0x55 / 255)
    static let mutedDark = Color(red: 0xB3 / 255, green: 0xA6 / 255, blue: 0x98 / 255)
    static let accent = Color(red: 0x4A / 255, green: 0x6A / 255, blue: 0x7E / 255)
    static let accentDark = Color(red: 0x8F / 255, green: 0xB8 / 255, blue: 0xCF / 255)
    static let danger = Color(red: 0xA8 / 255, green: 0x58 / 255, blue: 0x4A / 255)
    static let blue = Color(red: 0xC9 / 255, green: 0xDC / 255, blue: 0xE8 / 255)
}
