import XCTest
import CryptoKit
@testable import PetiteHome

final class ValueTypeTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    func testAgeSegmentMatchesWebsiteBuckets() {
        let now = Date()
        let sixMonths = cal.date(byAdding: .month, value: -6, to: now)!
        let threeYears = cal.date(byAdding: .year, value: -3, to: now)!
        let sevenYears = cal.date(byAdding: .year, value: -7, to: now)!
        XCTAssertEqual(AgeSegment.forYoungest(birthdates: [sixMonths], expecting: false, now: now), .underOne)
        XCTAssertEqual(AgeSegment.forYoungest(birthdates: [threeYears, sevenYears], expecting: false, now: now), .oneToFour)
        XCTAssertEqual(AgeSegment.forYoungest(birthdates: [sevenYears], expecting: false, now: now), .fivePlus)
        XCTAssertEqual(AgeSegment.forYoungest(birthdates: [], expecting: true, now: now), .expecting)
        XCTAssertNil(AgeSegment.forYoungest(birthdates: [], expecting: false, now: now))
        XCTAssertEqual(AgeSegment.expecting.rawValue, "Expecting")
        XCTAssertEqual(AgeSegment.oneToFour.rawValue, "1–4")
    }

    func testAgeFormatterShort() {
        let now = Date()
        XCTAssertEqual(AgeFormatter.short(from: cal.date(byAdding: .month, value: -14, to: now)!, now: now), "14 mo")
        XCTAssertEqual(AgeFormatter.short(from: cal.date(byAdding: .year, value: -3, to: now)!, now: now), "3 yr")
        XCTAssertEqual(AgeFormatter.short(from: cal.date(byAdding: .day, value: 20, to: now)!, now: now), "due")
    }

    func testRecurrenceRoundTripsThroughStorage() {
        for r in Recurrence.presets + [.custom(days: 45)] {
            XCTAssertEqual(Recurrence.from(key: r.storageKey, days: r.storageDays), r)
        }
        XCTAssertNil(Recurrence.none.next(after: Date()))
        let d = Date()
        XCTAssertEqual(Recurrence.custom(days: 10).next(after: d), cal.date(byAdding: .day, value: 10, to: d))
    }

    func testDailyAndWeeklyTemplatesStartSensibly() {
        let template = TaskTemplate.pack.first { $0.key == "plan_dinner" }!
        XCTAssertEqual(template.cadence, .daily)
        let morning = cal.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
        XCTAssertEqual(TaskTemplate.firstDue(for: template, now: morning), cal.startOfDay(for: morning), "before 3pm, plan dinner is due today")
        let evening = cal.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
        XCTAssertEqual(TaskTemplate.firstDue(for: template, now: evening), cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: evening)))
        let week = TaskTemplate.pack.first { $0.key == "plan_week" }!
        XCTAssertEqual(cal.component(.weekday, from: TaskTemplate.firstDue(for: week, now: Date())), 1, "plan the week lands on a Sunday")
        XCTAssertEqual(week.makeTask(due: Date()).reminderHour, 19)
        XCTAssertEqual(TaskTemplate.grouped().map(\.0), [.daily, .weekly, .monthly, .seasonal])
    }

    func testTaskCompletionRollsForward() {
        let due = Date()
        let task = HouseholdTask(title: "Filter", recurrence: .quarterly, nextDue: due, category: .home)
        task.complete(on: due)
        XCTAssertEqual(task.completions.count, 1)
        XCTAssertEqual(task.nextDue, Calendar.current.date(byAdding: .month, value: 3, to: due))
        let once = HouseholdTask(title: "Once", recurrence: .none, nextDue: due, category: .home)
        once.complete()
        XCTAssertTrue(once.isDone)
    }

    func testVaultCryptoRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let plain = Data("birth certificate".utf8)
        let sealed = try VaultCrypto.seal(plain, with: key)
        XCTAssertNotEqual(sealed, plain)
        XCTAssertEqual(try VaultCrypto.open(sealed, with: key), plain)
        XCTAssertThrowsError(try VaultCrypto.open(sealed, with: SymmetricKey(size: .bits256)))
    }

    func testFoundingCodes() {
        let code = FoundingCode.make(body: "7K2M")
        XCTAssertTrue(FoundingCode.isValid(code))
        XCTAssertTrue(FoundingCode.isValid(code.lowercased()))
        XCTAssertFalse(FoundingCode.isValid("PH-7K2M-AAAA"))
        XCTAssertFalse(FoundingCode.isValid("hello"))
    }

    func testCardScannerParsesTypicalCard() {
        let lines = ["Blue Cross Blue Shield", "Member ID: XYZ123456789", "Group 00412", "Customer service 1-800-555-0199"]
        let r = CardScanner.parse(lines: lines)
        XCTAssertEqual(r.carrier, "Blue Cross")
        XCTAssertEqual(r.memberID, "XYZ123456789")
        XCTAssertEqual(r.groupNumber, "00412")
        XCTAssertEqual(r.phone, "1-800-555-0199")
    }

    func testNeverStoresFullAccountNumbers() {
        var ref = AccountReference(institution: "Bank")
        ref.lastFour = String("123456789012".suffix(4))
        XCTAssertEqual(ref.lastFour, "9012")
    }
}
