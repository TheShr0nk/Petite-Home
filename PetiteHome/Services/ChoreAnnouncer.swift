import Foundation
import SwiftData

/// "Casey added a chore": when a chore created on the other adult's phone
/// arrives through iCloud, this phone posts one local notification for it.
/// Runs on launch, on foreground, and when a silent CloudKit push wakes the
/// app. Each chore is announced once per phone.
@MainActor
enum ChoreAnnouncer {
    private static let announcedKey = "chores.announced"
    private static let installedKey = "app.installedAt"
    private static let defaults = UserDefaults.standard

    private static var installedAt: Date {
        if let d = defaults.object(forKey: installedKey) as? Date { return d }
        let now = Date(); defaults.set(now, forKey: installedKey); return now
    }

    static func announce(household: Household, me: Adult?) async {
        guard await NotificationService.shared.authorizationStatus() == .authorized else { return }
        var announced = Set(defaults.stringArray(forKey: announcedKey) ?? [])
        let since = installedAt
        for task in household.tasks ?? [] where !task.isDone && task.createdAt > since && !announced.contains(task.uuid.uuidString) {
            announced.insert(task.uuid.uuidString)
            guard let by = task.createdByAdultID, by != me?.uuid else { continue }
            let who = household.adults.first { $0.uuid == by }?.displayName ?? "Your partner"
            let forWhom: String
            if let a = task.assignedTo { forWhom = a.uuid == me?.uuid ? "for you" : "for \(a.displayName)" } else { forWhom = "for either of you" }
            let when = Calendar.current.isDateInToday(task.nextDue) ? "today" : task.nextDue.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            NotificationService.shared.postNow(id: "newchore.\(task.uuid.uuidString)",
                                               title: "\(who) added a chore",
                                               body: "\(task.title) · \(task.recurrence.label.lowercased()) · \(when), \(forWhom)",
                                               deepLink: "petitehome://tasks")
        }
        defaults.set(Array(announced.suffix(500)), forKey: announcedKey)
    }
}
