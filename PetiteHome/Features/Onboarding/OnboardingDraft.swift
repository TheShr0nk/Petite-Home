import Foundation
import SwiftData
import Observation

/// Everything the user tells us before Sign in with Apple. Lives in memory
/// until "Save my Family File", then becomes the Household.
@MainActor
@Observable
final class OnboardingDraft {
    struct ChildDraft: Identifiable, Hashable {
        var id = UUID()
        var firstName = ""
        var dateOfBirth: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        var ageShort: String { AgeFormatter.short(from: dateOfBirth) }
    }

    var includesMe = true
    var includesPartner = false
    var partnerFirstName = ""
    var isExpecting = false
    var children: [ChildDraft] = []

    var firstContact = Contact()
    var pediatrician = Contact()
    var pediatricianForAll = true
    var healthInsurance = InsurancePolicy()
    var guardian = Contact()
    var guardianUndecided = false

    var appleUserID: String?
    var appleEmail: String?
    var appleGivenName: String?
    var appleFamilyName: String?

    var youngest: ChildDraft? { children.max(by: { $0.dateOfBirth < $1.dateOfBirth }) }
    var segment: AgeSegment? { AgeSegment.forYoungest(birthdates: children.map(\.dateOfBirth), expecting: isExpecting) }

    /// A throwaway file so the reveal screen can score the draft before anything is saved.
    func previewReport() -> CompletenessReport {
        let file = FamilyFile()
        if firstContact.isFilled { file.emergencyContacts = [firstContact] }
        file.healthInsurance = healthInsurance
        if guardian.isFilled { file.designatedGuardian = guardian }
        let doctors: [Contact?] = children.map { c in
            (pediatrician.isFilled && (pediatricianForAll || c.id == youngest?.id)) ? pediatrician : nil
        }
        return Completeness.report(file: file, childPediatricians: doctors)
    }

    /// Writes the draft into the store as a real Household.
    @discardableResult
    func commit(into context: ModelContext) -> Household {
        let household = Household()
        context.insert(household)
        household.ownerAppleUserID = appleUserID
        household.isExpecting = isExpecting
        household.guardianUndecided = guardianUndecided
        household.youngestChildSegment = segment

        let me = Adult(firstName: appleGivenName ?? "Me", lastName: appleFamilyName ?? "", role: .parent, isAccountOwner: true)
        me.email = appleEmail ?? ""
        household.members = [me]
        if includesPartner {
            household.members?.append(Adult(firstName: partnerFirstName.isEmpty ? "Partner" : partnerFirstName, role: .parent))
        }

        household.children = children.map { draft in
            let child = Child(firstName: draft.firstName, dateOfBirth: draft.dateOfBirth)
            if pediatrician.isFilled, pediatricianForAll || draft.id == youngest?.id {
                child.pediatrician = pediatrician
            }
            return child
        }

        let file = FamilyFile()
        if firstContact.isFilled { file.emergencyContacts = [firstContact] }
        file.healthInsurance = healthInsurance
        if guardian.isFilled { file.designatedGuardian = guardian }
        household.familyFile = file
        try? context.save()
        return household
    }
}
