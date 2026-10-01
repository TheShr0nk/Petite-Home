import Foundation
import EventKit
import SwiftData
import UIKit

/// Puts the household's tasks, plans, meals and expirations into the phone's
/// own Reminders and Calendar apps, in a list and a calendar both named
/// "Petite Home", so it is obvious where they came from.
///
/// The app is the source of truth. Items are written out and re-pointed
/// after every change; a task checked off in Reminders is read back and
/// completed in the app on the next sync. Identifiers are per phone, so each
/// partner's phone keeps its own copies.
@MainActor
final class PhoneSyncService {
    static let shared = PhoneSyncService()

    static let listName = "Petite Home"
    private let defaults = UserDefaults.standard
    private let mapKey = "phoneSync.identifiers"
    private let tasksKey = "phoneSync.tasksEnabled"
    private let calendarKey = "phoneSync.calendarEnabled"

    private var store: EKEventStore { CalendarSyncService.shared.store }

    private init() {}

    // MARK: Settings (per phone)

    var tasksToReminders: Bool {
        get { defaults.bool(forKey: tasksKey) }
        set { defaults.set(newValue, forKey: tasksKey) }
    }
    var plansToCalendar: Bool {
        get { defaults.bool(forKey: calendarKey) }
        set { defaults.set(newValue, forKey: calendarKey) }
    }
    var isEnabled: Bool { tasksToReminders || plansToCalendar }

    var hasRemindersAccess: Bool { EKEventStore.authorizationStatus(for: .reminder) == .fullAccess }
    var hasCalendarAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    func requestRemindersAccess() async -> Bool { (try? await store.requestFullAccessToReminders()) ?? false }
    func requestCalendarAccess() async -> Bool { (try? await store.requestFullAccessToEvents()) ?? false }

    // MARK: The Petite Home list and calendar

    private func source() -> EKSource? {
        store.sources.first { $0.sourceType == .calDAV && $0.title.lowercased().contains("icloud") }
            ?? store.defaultCalendarForNewEvents?.source
            ?? store.sources.first { $0.sourceType == .local }
    }

    private func calendar(for type: EKEntityType) -> EKCalendar? {
        if let existing = store.calendars(for: type).first(where: { $0.title == Self.listName }) { return existing }
        guard let source = source() else { return nil }
        let cal = EKCalendar(for: type, eventStore: store)
        cal.title = Self.listName
        cal.source = source
        cal.cgColor = Theme.Colors.uiPowderBlueDk.cgColor
        do { try store.saveCalendar(cal, commit: true) } catch { return nil }
        return cal
    }

    // MARK: Identifier map (model uuid -> EventKit identifier, this phone only)

    private var map: [String: String] {
        get { defaults.dictionary(forKey: mapKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: mapKey) }
    }

    private static let footer = "Added by Petite Home. Change it in the app and it updates here."

    // MARK: Sync

    /// Runs whatever is switched on. Safe to call often; premium only.
    func syncIfEnabled(household: Household, context: ModelContext, isPremium: Bool) {
        guard isPremium else { return }
        if tasksToReminders, hasRemindersAccess { syncTasks(household: household, context: context) }
        if plansToCalendar, hasCalendarAccess { syncCalendar(household: household) }
    }

    /// Tasks → one reminder each in the Petite Home list, due at the task's hour. No EventKit
    /// recurrence: the app rolls the task forward and re-points the reminder, which keeps the two
    /// from double-advancing. A reminder completed in the Reminders app completes the task.
    func syncTasks(household: Household, context: ModelContext) {
        guard let list = calendar(for: .reminder) else { return }
        var ids = map
        var touched = false
        for task in household.tasks ?? [] {
            let key = "task:\(task.uuid.uuidString)"
            var reminder: EKReminder? = ids[key].flatMap { store.calendarItem(withIdentifier: $0) as? EKReminder }
            if task.isDone {
                if let r = reminder { r.isCompleted = true; try? store.save(r, commit: false); touched = true }
                continue
            }
            // Read back a completion made in the Reminders app.
            if let r = reminder, r.isCompleted, let done = r.completionDate, done > (task.completions.last ?? .distantPast) {
                task.complete(on: done)
            }
            if reminder == nil {
                let r = EKReminder(eventStore: store)
                r.calendar = list
                reminder = r
            }
            guard let r = reminder else { continue }
            r.title = task.title
            r.notes = [task.notes, task.assignedTo.map { "For \($0.displayName)." } ?? "", Self.footer].filter { !$0.isEmpty }.joined(separator: "\n\n")
            r.priority = task.isOverdue ? 1 : 0
            r.isCompleted = false
            r.completionDate = nil
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: task.nextDue)
            comps.hour = task.reminderHour; comps.minute = 0
            r.dueDateComponents = comps
            r.alarms = nil
            if let fire = Calendar.current.date(from: comps) { r.addAlarm(EKAlarm(absoluteDate: fire)) }
            do {
                try store.save(r, commit: false)
                ids[key] = r.calendarItemIdentifier
                touched = true
            } catch { continue }
        }
        // Remove reminders whose task is gone.
        let live = Set((household.tasks ?? []).map { "task:\($0.uuid.uuidString)" })
        for (key, id) in ids where key.hasPrefix("task:") && !live.contains(key) {
            if let r = store.calendarItem(withIdentifier: id) as? EKReminder { try? store.remove(r, commit: false) }
            ids.removeValue(forKey: key); touched = true
        }
        if touched { try? store.commit() }
        map = ids
        try? context.save()
    }

    /// Plans, meals and expirations → events in the Petite Home calendar.
    func syncCalendar(household: Household) {
        guard let cal = calendar(for: .event) else { return }
        var ids = map
        var touched = false
        var live = Set<String>()

        func upsert(key: String, title: String, start: Date, end: Date, allDay: Bool, notes: String, location: String = "") {
            live.insert(key)
            let event = ids[key].flatMap { store.event(withIdentifier: $0) } ?? EKEvent(eventStore: store)
            event.calendar = cal
            event.title = title
            event.startDate = start
            event.endDate = end
            event.isAllDay = allDay
            event.notes = notes + "\n\n" + Self.footer
            event.location = location.isEmpty ? nil : location
            event.url = URL(string: "petitehome://open")
            do {
                try store.save(event, span: .thisEvent, commit: false)
                ids[key] = event.eventIdentifier
                touched = true
            } catch {}
        }

        let cal_ = Calendar.current
        for plan in household.plans ?? [] where !plan.isPast {
            let end = plan.endDate ?? (cal_.date(byAdding: .hour, value: 2, to: plan.startDate) ?? plan.startDate)
            var notes = plan.notes
            if plan.sitterStatus != .notNeeded {
                let sitter = household.sitters.first { $0.id == plan.sitterID }?.name
                notes += (notes.isEmpty ? "" : "\n") + "Kids: \(plan.sitterStatus.label)\(sitter.map { " · \($0)" } ?? "")"
            }
            upsert(key: "plan:\(plan.uuid.uuidString)", title: plan.displayTitle, start: plan.startDate, end: end, allDay: false, notes: notes, location: plan.location)
        }
        let today = cal_.startOfDay(for: Date())
        for meal in household.meals ?? [] where meal.date >= today {
            let start = cal_.date(byAdding: .hour, value: meal.slot.hour, to: cal_.startOfDay(for: meal.date)) ?? meal.date
            let cook = household.adults.first { $0.uuid == meal.cookAdultID }?.displayName
            upsert(key: "meal:\(meal.uuid.uuidString)", title: "\(meal.slot.label): \(meal.displayTitle)", start: start, end: start.addingTimeInterval(45 * 60), allDay: false,
                   notes: [cook.map { "\($0) cooks." } ?? "", meal.notes].filter { !$0.isEmpty }.joined(separator: "\n"))
        }
        for exp in ExpirationScheduler.expirations(for: household) where exp.date >= today {
            let day = cal_.startOfDay(for: exp.date)
            upsert(key: "exp:\(exp.id.uuidString)", title: "Expires: \(exp.title)", start: day, end: cal_.date(byAdding: .day, value: 1, to: day) ?? day, allDay: true, notes: "")
        }
        for (key, id) in ids where (key.hasPrefix("plan:") || key.hasPrefix("meal:") || key.hasPrefix("exp:")) && !live.contains(key) {
            if let e = store.event(withIdentifier: id) { try? store.remove(e, span: .thisEvent, commit: false) }
            ids.removeValue(forKey: key); touched = true
        }
        if touched { try? store.commit() }
        map = ids
    }

    /// Turns a channel off and clears what it wrote.
    func disableTasks() {
        tasksToReminders = false
        var ids = map
        for (key, id) in ids where key.hasPrefix("task:") {
            if let r = store.calendarItem(withIdentifier: id) as? EKReminder { try? store.remove(r, commit: false) }
            ids.removeValue(forKey: key)
        }
        try? store.commit(); map = ids
    }

    func disableCalendar() {
        plansToCalendar = false
        var ids = map
        for (key, id) in ids where !key.hasPrefix("task:") {
            if let e = store.event(withIdentifier: id) { try? store.remove(e, span: .thisEvent, commit: false) }
            ids.removeValue(forKey: key)
        }
        try? store.commit(); map = ids
    }
}
