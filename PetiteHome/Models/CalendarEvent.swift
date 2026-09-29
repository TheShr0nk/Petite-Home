import Foundation
import SwiftData

/// A mirrored calendar event. Each phone reads its owner's chosen calendars
/// through EventKit and writes the next few weeks here; because the household
/// syncs through CloudKit, the partner sees them too. Only what's needed to
/// plan around each other is kept: title, time, which calendar, whose it is.
@Model
final class CalendarEvent {
    var id: UUID = UUID()
    /// EventKit's identifier on the device that mirrored it, so re-syncs update in place.
    var sourceIdentifier: String = ""
    var title: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    var isAllDay: Bool = false
    var location: String = ""
    var calendarName: String = ""
    /// The adult whose calendar this came from.
    var ownerAdultID: UUID? = nil
    var mirroredAt: Date = Date()

    var household: Household? = nil

    init(sourceIdentifier: String, title: String, startDate: Date, endDate: Date, isAllDay: Bool, calendarName: String, ownerAdultID: UUID?) {
        self.sourceIdentifier = sourceIdentifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarName = calendarName
        self.ownerAdultID = ownerAdultID
    }
}

/// One line on the Life Sync agenda: an event or a task, on a day.
struct AgendaItem: Identifiable, Hashable {
    enum Kind: Hashable { case event, task }
    let id: UUID
    let kind: Kind
    let title: String
    let start: Date
    let end: Date?
    let isAllDay: Bool
    let ownerAdultID: UUID?
    let detail: String
    let isOverdue: Bool
}

/// Pure: merges events and tasks into per-day agendas so it can be unit tested.
enum LifeSyncAgenda {
    struct Day: Identifiable {
        let date: Date
        let items: [AgendaItem]
        var id: Date { date }
    }

    static func build(events: [CalendarEvent], tasks: [HouseholdTask], from start: Date, days: Int, calendar: Calendar = .current) -> [Day] {
        let startOfFirst = calendar.startOfDay(for: start)
        return (0..<days).compactMap { offset -> Day? in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: startOfFirst),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
            var items: [AgendaItem] = []
            for e in events where e.startDate < dayEnd && e.endDate > dayStart {
                items.append(AgendaItem(id: e.id, kind: .event, title: e.title, start: e.startDate, end: e.endDate, isAllDay: e.isAllDay,
                                        ownerAdultID: e.ownerAdultID, detail: e.calendarName, isOverdue: false))
            }
            for t in tasks where !t.isDone {
                let due = calendar.startOfDay(for: t.nextDue)
                // Overdue tasks pile onto today so they are not lost in the past.
                let showsToday = offset == 0 && due < startOfFirst
                if due == dayStart || showsToday {
                    items.append(AgendaItem(id: t.id, kind: .task, title: t.title, start: dayStart, end: nil, isAllDay: true,
                                            ownerAdultID: t.assignedTo?.id, detail: t.recurrence.label, isOverdue: showsToday))
                }
            }
            items.sort { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                if a.start != b.start { return a.start < b.start }
                return a.title < b.title
            }
            return Day(date: dayStart, items: items)
        }
    }
}
