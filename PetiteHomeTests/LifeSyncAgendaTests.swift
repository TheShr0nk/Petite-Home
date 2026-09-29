import XCTest
import SwiftData
@testable import PetiteHome

@MainActor
final class LifeSyncAgendaTests: XCTestCase {
    private let cal = Calendar.current
    private var container: ModelContainer!

    override func setUp() async throws { container = PersistenceController.preview() }

    private func event(_ title: String, dayOffset: Int, hour: Int, owner: UUID) -> CalendarEvent {
        let day = cal.date(byAdding: .day, value: dayOffset, to: cal.startOfDay(for: Date()))!
        let start = cal.date(byAdding: .hour, value: hour, to: day)!
        let e = CalendarEvent(sourceIdentifier: title, title: title, startDate: start, endDate: start.addingTimeInterval(3600), isAllDay: false, calendarName: "Home", ownerAdultID: owner)
        container.mainContext.insert(e)
        return e
    }

    func testEventsLandOnTheirDayAndSortByTime() {
        let me = UUID(), them = UUID()
        let events = [event("Dentist", dayOffset: 1, hour: 14, owner: me), event("Daycare pickup", dayOffset: 1, hour: 9, owner: them), event("Standup", dayOffset: 3, hour: 10, owner: me)]
        let days = LifeSyncAgenda.build(events: events, tasks: [], from: Date(), days: 7)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days[0].items.count, 0)
        XCTAssertEqual(days[1].items.map(\.title), ["Daycare pickup", "Dentist"])
        XCTAssertEqual(days[3].items.first?.ownerAdultID, me)
    }

    func testTasksSitOnTheirDueDayAndOverdueOnesPileOntoToday() {
        let today = cal.startOfDay(for: Date())
        let due = HouseholdTask(title: "Furnace filter", recurrence: .quarterly, nextDue: cal.date(byAdding: .day, value: 2, to: today)!, category: .home)
        let late = HouseholdTask(title: "Smoke batteries", recurrence: .semiannual, nextDue: cal.date(byAdding: .day, value: -5, to: today)!, category: .home)
        let done = HouseholdTask(title: "Once", recurrence: .none, nextDue: today, category: .home)
        done.complete()
        for t in [due, late, done] { container.mainContext.insert(t) }
        let days = LifeSyncAgenda.build(events: [], tasks: [due, late, done], from: Date(), days: 3)
        XCTAssertEqual(days[0].items.map(\.title), ["Smoke batteries"])
        XCTAssertTrue(days[0].items[0].isOverdue)
        XCTAssertEqual(days[2].items.map(\.title), ["Furnace filter"])
    }

    func testAllDayItemsComeFirst() {
        let me = UUID()
        let timed = event("Lunch", dayOffset: 0, hour: 12, owner: me)
        let task = HouseholdTask(title: "Car seat check", recurrence: .monthly, nextDue: Date(), category: .kids)
        container.mainContext.insert(task)
        let day = LifeSyncAgenda.build(events: [timed], tasks: [task], from: Date(), days: 1)[0]
        XCTAssertEqual(day.items.map(\.kind), [.task, .event])
    }
}
