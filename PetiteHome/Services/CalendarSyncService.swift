import Foundation
import EventKit
import SwiftData

/// Life Sync: mirrors the current adult's chosen calendars into the household
/// so their partner sees them. Reads through EventKit on this phone only;
/// nothing is written back to the calendar, and no calendar leaves the
/// family's iCloud account.
@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()
    static let horizonDays = 42

    let store = EKEventStore()
    private let selectionKey = "lifeSync.selectedCalendarIDs"

    private init() {
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            NotificationCenter.default.post(name: .calendarSourceChanged, object: nil)
        }
    }

    var hasAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    func requestAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    /// Every calendar on this phone, grouped the way the Calendar app shows them.
    func calendars() -> [EKCalendar] {
        store.calendars(for: .event).sorted { ($0.source.title, $0.title) < ($1.source.title, $1.title) }
    }

    var selectedCalendarIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: selectionKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: selectionKey) }
    }

    /// Re-mirrors the selected calendars for `adult` into `household`. Safe to call often.
    func sync(adult: Adult, household: Household, context: ModelContext) {
        guard hasAccess, adult.calendarSyncEnabled else { return }
        let chosen = calendars().filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !chosen.isEmpty else { return }

        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: Self.horizonDays, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: chosen)
        let fresh = store.events(matching: predicate)

        var existing: [String: CalendarEvent] = [:]
        for e in household.calendarEvents ?? [] where e.ownerAdultID == adult.uuid {
            existing[e.sourceIdentifier] = e
        }

        var seen = Set<String>()
        for ek in fresh {
            // Recurring events share an identifier; key on the occurrence start as well.
            let key = "\(ek.eventIdentifier ?? UUID().uuidString)@\(Int(ek.startDate.timeIntervalSince1970))"
            seen.insert(key)
            if let mirrored = existing[key] {
                mirrored.title = ek.title ?? ""
                mirrored.startDate = ek.startDate
                mirrored.endDate = ek.endDate
                mirrored.isAllDay = ek.isAllDay
                mirrored.location = ek.location ?? ""
                mirrored.calendarName = ek.calendar.title
                mirrored.mirroredAt = Date()
            } else {
                let mirrored = CalendarEvent(sourceIdentifier: key, title: ek.title ?? "", startDate: ek.startDate, endDate: ek.endDate,
                                             isAllDay: ek.isAllDay, calendarName: ek.calendar.title, ownerAdultID: adult.uuid)
                mirrored.location = ek.location ?? ""
                household.calendarEvents?.append(mirrored)
            }
        }
        // Anything this adult mirrored before that is gone from the calendar, or past the horizon, is removed.
        for (key, stale) in existing where !seen.contains(key) {
            context.delete(stale)
        }
        adult.calendarSyncedAt = Date()
        try? context.save()
    }

    /// Turns Life Sync off for this adult and clears what they mirrored.
    func disable(adult: Adult, household: Household, context: ModelContext) {
        adult.calendarSyncEnabled = false
        adult.calendarSyncedAt = nil
        for e in household.calendarEvents ?? [] where e.ownerAdultID == adult.uuid { context.delete(e) }
        try? context.save()
    }
}

extension Notification.Name {
    static let calendarSourceChanged = Notification.Name("co.petitehome.calendarSourceChanged")
}
