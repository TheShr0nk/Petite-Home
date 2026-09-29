import XCTest
import SwiftData
@testable import PetiteHome

@MainActor
final class CompletenessTests: XCTestCase {
    private var container: ModelContainer!

    override func setUp() async throws {
        container = PersistenceController.preview()
    }

    private func household(withChildren count: Int) -> (Household, FamilyFile) {
        let h = Household()
        let f = FamilyFile()
        h.familyFile = f
        for i in 0..<count {
            h.children?.append(Child(firstName: "Kid\(i)", dateOfBirth: Calendar.current.date(byAdding: .year, value: -2, to: Date())!))
        }
        container.mainContext.insert(h)
        return (h, f)
    }

    func testEmptyFileIsZero() {
        let (h, f) = household(withChildren: 1)
        XCTAssertEqual(Completeness.report(file: f, household: h).percent, 0)
    }

    func testWeightsSumToOneHundredWithChildren() {
        let (h, f) = household(withChildren: 1)
        let report = Completeness.report(file: f, household: h)
        // Auto insurance only counts once a vehicle is known, so the base is 97.
        XCTAssertEqual(report.items.reduce(0) { $0 + $1.weight }, 97)
    }

    func testFirstEmergencyContactIsAboutEightPercent() {
        let (h, f) = household(withChildren: 1)
        f.emergencyContacts = [Contact(name: "Sam", relationship: "Sibling", phone: "555")]
        XCTAssertEqual(Completeness.report(file: f, household: h).percent, 8)
    }

    func testOnboardingLandsInTheTwentiesToThirties() {
        let (h, f) = household(withChildren: 1)
        f.emergencyContacts = [Contact(name: "Sam")]
        f.healthInsurance = InsurancePolicy(carrier: "Aetna")
        f.designatedGuardian = Contact(name: "Jo")
        h.kids.first?.pediatrician = Contact(name: "Dr. Lee")
        let p = Completeness.report(file: f, household: h).percent
        XCTAssert((25...35).contains(p), "expected 25–35, got \(p)")
    }

    func testNextToAddIsOrderedByValue() {
        let (h, f) = household(withChildren: 1)
        f.emergencyContacts = [Contact(name: "Sam")]
        let next = Completeness.report(file: f, household: h).nextToAdd
        XCTAssertEqual(next.first, .healthInsurance)
        XCTAssertFalse(next.contains(.vetOrPetSitter), "optional fields never nag")
    }

    func testNoChildrenDropsChildFields() {
        let (h, f) = household(withChildren: 0)
        let report = Completeness.report(file: f, household: h)
        XCTAssertEqual(report.items.first { $0.field == .pediatrician }?.weight, 0)
        XCTAssertEqual(report.items.first { $0.field == .designatedGuardian }?.weight, 0)
    }

    func testFullFileIsOneHundred() {
        let (h, f) = household(withChildren: 1)
        let c = Contact(name: "X", phone: "1")
        f.emergencyContacts = [c, c]
        f.preferredHospital = c; f.homeAddress = "1 Main St"; f.spareKeyLocation = "Neighbor"
        f.healthInsurance = InsurancePolicy(carrier: "A"); f.dentalInsurance = InsurancePolicy(carrier: "D")
        f.familyDoctor = c; f.pharmacy = c
        h.kids.first?.pediatrician = c
        f.designatedGuardian = c; f.backupGuardian = c; f.whereTheWillIs = "Safe"; f.attorney = c; f.financialAdvisor = c
        f.lifeInsurance = [InsurancePolicy(carrier: "L")]; f.instructionsForKids = "Bedtime at 7"
        f.bankAccounts = [AccountReference(institution: "Bank")]; f.retirementAccounts = [AccountReference(institution: "401k")]
        f.mortgageOrLandlord = c; f.utilities = [AccountReference(institution: "Power")]; f.recurringBills = [AccountReference(institution: "Phone")]
        f.passwordManager = "1Password"
        f.homeownersOrRenters = InsurancePolicy(carrier: "H"); f.autoInsurance = InsurancePolicy(carrier: "Auto")
        f.vehicles = [Vehicle(yearMakeModel: "2020 Car")]
        XCTAssertEqual(Completeness.report(file: f, household: h).percent, 100)
    }

    func testBuckets() {
        XCTAssertEqual(CompletenessReport(items: []).bucket, "0-25")
    }
}
