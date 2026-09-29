import Foundation
import SwiftData

/// What the user chose for Life Sync during onboarding before they had
/// premium. Kept on this phone until the trial starts, then applied once.
enum LifeSyncPending {
    private static let calendarsKey = "lifeSync.pending.calendarIDs"
    private static let templatesKey = "lifeSync.pending.templateKeys"
    private static let wellChildKey = "lifeSync.pending.wellChild"

    static func save(calendarIDs: Set<String>, templateKeys: Set<String>, wellChild: Bool) {
        let d = UserDefaults.standard
        d.set(Array(calendarIDs), forKey: calendarsKey)
        d.set(Array(templateKeys), forKey: templatesKey)
        d.set(wellChild, forKey: wellChildKey)
    }

    static var exists: Bool {
        let d = UserDefaults.standard
        return d.object(forKey: calendarsKey) != nil || d.object(forKey: templatesKey) != nil
    }

    static func clear() {
        let d = UserDefaults.standard
        [calendarsKey, templatesKey, wellChildKey].forEach { d.removeObject(forKey: $0) }
    }

    /// Turns the saved choices into real state: mirrored calendars and template tasks. Premium only.
    @MainActor
    static func apply(to household: Household, adult: Adult?, context: ModelContext) {
        guard exists else { return }
        let d = UserDefaults.standard
        let calendarIDs = Set(d.stringArray(forKey: calendarsKey) ?? [])
        let templateKeys = Set(d.stringArray(forKey: templatesKey) ?? [])
        let wellChild = d.bool(forKey: wellChildKey)

        let existing = (household.tasks ?? []).compactMap(\.templateKey)
        for t in TaskTemplate.pack where templateKeys.contains(t.key) && !existing.contains(t.key) {
            household.tasks?.append(t.makeTask(due: TaskTemplate.firstDue(for: t)))
        }
        if wellChild {
            for child in household.kids {
                let t = TaskTemplate.wellChild(for: child)
                guard !existing.contains(t.key) else { continue }
                household.tasks?.append(t.makeTask(due: TaskTemplate.firstDue(for: t, child: child)))
            }
        }
        if let adult, !calendarIDs.isEmpty, CalendarSyncService.shared.hasAccess {
            CalendarSyncService.shared.selectedCalendarIDs = calendarIDs
            adult.calendarSyncEnabled = true
            CalendarSyncService.shared.sync(adult: adult, household: household, context: context)
            Analytics.track(.lifeSyncEnabled, ["calendars": calendarIDs.count, "from": "onboarding"])
        }
        try? context.save()
        ExpirationScheduler.sync(household: household, isPremium: true)
        clear()
    }
}
