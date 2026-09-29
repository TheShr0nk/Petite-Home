import XCTest
import SwiftData
@testable import PetiteHome

@MainActor
final class PlansTests: XCTestCase {
    private var container: ModelContainer!
    private let cal = Calendar.current
    override func setUp() async throws { container = PersistenceController.preview() }

    private func event(day: Int, hour: Int, length: Int = 1, allDay: Bool = false) -> CalendarEvent {
        let start = cal.date(byAdding: .hour, value: hour, to: cal.date(byAdding: .day, value: day, to: cal.startOfDay(for: Date()))!)!
        let e = CalendarEvent(sourceIdentifier: UUID().uuidString, title: "x", startDate: start, endDate: start.addingTimeInterval(Double(length) * 3600), isAllDay: allDay, calendarName: "c", ownerAdultID: nil)
        container.mainContext.insert(e)
        return e
    }

    func testFreeEveningsSkipBusyNightsAndExistingPlans() {
        let now = cal.startOfDay(for: Date()) // morning, so tonight counts
        let busyTomorrow = event(day: 1, hour: 19)
        let daytimeOnly = event(day: 2, hour: 10, length: 2)
        let allDay = event(day: 3, hour: 0, length: 24, allDay: true)
        let plan = FamilyPlan(title: "Trip", kind: .trip, startDate: cal.date(byAdding: .day, value: 4, to: now)!)
        container.mainContext.insert(plan)
        let free = FreeEveningFinder.find(events: [busyTomorrow, daytimeOnly, allDay], plans: [plan], from: now, days: 6, weekendsFirst: false)
        let offsets = free.map { cal.dateComponents([.day], from: now, to: $0.date).day! }
        XCTAssertEqual(offsets, [0, 2, 3, 5])
    }

    func testWeekendsComeFirst() {
        let now = cal.startOfDay(for: Date())
        let free = FreeEveningFinder.find(events: [], plans: [], from: now, days: 14)
        XCTAssertEqual(free.count, 14)
        XCTAssertTrue(cal.isDateInWeekend(free[0].date))
        XCTAssertFalse(cal.isDateInWeekend(free.last!.date))
    }

    func testPlanKindSetsSitterDefault() {
        XCTAssertEqual(FamilyPlan(title: "", kind: .dateNight, startDate: Date()).sitterStatus, .needed)
        XCTAssertEqual(FamilyPlan(title: "", kind: .outing, startDate: Date()).sitterStatus, .notNeeded)
    }

    func testSitterSheetPullsFromTheBinderButNeverCodes() {
        let h = Household()
        container.mainContext.insert(h)
        let me = Adult(firstName: "Casey", isAccountOwner: true); me.phone = "555-0100"
        h.members = [me]
        let kid = Child(firstName: "Theo", dateOfBirth: cal.date(byAdding: .year, value: -2, to: Date())!)
        kid.allergies = ["Peanuts"]; kid.notes = "Bedtime at 7. Bunny is essential."
        kid.pediatrician = Contact(name: "Dr. Lee", phone: "555-0199")
        h.children = [kid]
        let file = FamilyFile()
        file.emergencyContacts = [Contact(name: "Sam", relationship: "Sibling", phone: "555-0111")]
        file.homeAddress = "1 Main St"; file.hasAlarmCode = true; file.passwordManager = "1Password, in the safe"
        h.familyFile = file
        let plan = FamilyPlan(title: "Dinner", kind: .dateNight, startDate: Date())
        plan.location = "Lucia's"
        let text = SitterSheet.text(plan: plan, household: h, sitterName: "Maria Gomez")
        XCTAssertTrue(text.hasPrefix("Hi Maria"))
        XCTAssertTrue(text.contains("Peanuts"))
        XCTAssertTrue(text.contains("Bunny is essential"))
        XCTAssertTrue(text.contains("Sam (Sibling): 555-0111"))
        XCTAssertTrue(text.contains("Dr. Lee"))
        XCTAssertTrue(text.contains("1 Main St"))
        XCTAssertFalse(text.contains("1Password"))
        XCTAssertFalse(text.lowercased().contains("alarm"))
        XCTAssertTrue(SitterSheet.askText(plan: plan, sitterName: "Maria Gomez").hasPrefix("Hi Maria, any chance"))
    }

    func testPlansLandOnTheAgendaWithSitterState() {
        let plan = FamilyPlan(title: "Date night", kind: .dateNight, startDate: cal.date(byAdding: .hour, value: 19, to: cal.startOfDay(for: Date()))!)
        container.mainContext.insert(plan)
        let day = LifeSyncAgenda.build(events: [], tasks: [], plans: [plan], from: Date(), days: 1)[0]
        XCTAssertEqual(day.items.first?.kind, .plan)
        XCTAssertTrue(day.items.first!.isOverdue, "needs a sitter surfaces as attention")
    }
}
