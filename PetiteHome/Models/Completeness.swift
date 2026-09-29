import Foundation

/// The five sections of the Family File, in the order they appear.
enum FamilyFileSection: String, CaseIterable, Identifiable, Codable {
    case emergency, medical, ifSomethingHappens, accounts, homeAndVehicles
    var id: String { rawValue }

    var title: String {
        switch self {
        case .emergency: return "In an emergency"
        case .medical: return "Medical"
        case .ifSomethingHappens: return "If something happens to us"
        case .accounts: return "Accounts and money"
        case .homeAndVehicles: return "Home and vehicles"
        }
    }
    var systemImage: String {
        switch self {
        case .emergency: return "phone.arrow.up.right"
        case .medical: return "cross.case"
        case .ifSomethingHappens: return "person.2"
        case .accounts: return "building.columns"
        case .homeAndVehicles: return "house"
        }
    }
}

/// Every field in the Family File that counts toward completeness, addressable
/// by a stable key so notifications and the Home card can deep link to it.
enum FamilyFileField: String, CaseIterable, Identifiable, Codable {
    // Section 1
    case emergencyContactFirst, emergencyContactSecond, preferredHospital, homeAddress, keysAndCodes, vetOrPetSitter
    // Section 2
    case healthInsurance, pediatrician, familyDoctor, pharmacy, dentalInsurance
    // Section 3
    case designatedGuardian, backupGuardian, whereTheWillIs, attorney, financialAdvisor, lifeInsurance, instructionsForKids
    // Section 4
    case bankAccounts, retirementAccounts, mortgageOrLandlord, utilities, recurringBills, passwordManager
    // Section 5
    case homeownersOrRenters, autoInsurance, vehicles

    var id: String { rawValue }

    var section: FamilyFileSection {
        switch self {
        case .emergencyContactFirst, .emergencyContactSecond, .preferredHospital, .homeAddress, .keysAndCodes, .vetOrPetSitter:
            return .emergency
        case .healthInsurance, .pediatrician, .familyDoctor, .pharmacy, .dentalInsurance:
            return .medical
        case .designatedGuardian, .backupGuardian, .whereTheWillIs, .attorney, .financialAdvisor, .lifeInsurance, .instructionsForKids:
            return .ifSomethingHappens
        case .bankAccounts, .retirementAccounts, .mortgageOrLandlord, .utilities, .recurringBills, .passwordManager:
            return .accounts
        case .homeownersOrRenters, .autoInsurance, .vehicles:
            return .homeAndVehicles
        }
    }

    /// Weight toward the 0–100 score. Weights sum to 100 for a household with children.
    var weight: Int {
        switch self {
        case .emergencyContactFirst: return 8
        case .emergencyContactSecond: return 3
        case .preferredHospital: return 4
        case .homeAddress: return 5
        case .keysAndCodes: return 2
        case .vetOrPetSitter: return 0        // optional; listed, never blocks 100
        case .healthInsurance: return 8
        case .pediatrician: return 6
        case .familyDoctor: return 3
        case .pharmacy: return 3
        case .dentalInsurance: return 2
        case .designatedGuardian: return 8
        case .backupGuardian: return 3
        case .whereTheWillIs: return 8
        case .attorney: return 2
        case .financialAdvisor: return 1
        case .lifeInsurance: return 3
        case .instructionsForKids: return 3
        case .bankAccounts: return 7
        case .retirementAccounts: return 2
        case .mortgageOrLandlord: return 3
        case .utilities: return 2
        case .recurringBills: return 1
        case .passwordManager: return 3
        case .homeownersOrRenters: return 4
        case .autoInsurance: return 3
        case .vehicles: return 3
        }
    }

    var label: String {
        switch self {
        case .emergencyContactFirst: return "Who to call first"
        case .emergencyContactSecond: return "Second emergency contact"
        case .preferredHospital: return "Preferred hospital"
        case .homeAddress: return "Home address"
        case .keysAndCodes: return "Spare key, gate and alarm"
        case .vetOrPetSitter: return "Vet or pet sitter"
        case .healthInsurance: return "Health insurance"
        case .pediatrician: return "Pediatrician"
        case .familyDoctor: return "Family doctor"
        case .pharmacy: return "Pharmacy"
        case .dentalInsurance: return "Dental insurance"
        case .designatedGuardian: return "Who would care for the kids"
        case .backupGuardian: return "Backup guardian"
        case .whereTheWillIs: return "Where the will is"
        case .attorney: return "Attorney"
        case .financialAdvisor: return "Financial advisor"
        case .lifeInsurance: return "Life insurance"
        case .instructionsForKids: return "Notes for whoever has the kids"
        case .bankAccounts: return "Bank accounts"
        case .retirementAccounts: return "Retirement accounts"
        case .mortgageOrLandlord: return "Mortgage or landlord"
        case .utilities: return "Utilities"
        case .recurringBills: return "Recurring bills"
        case .passwordManager: return "Password manager"
        case .homeownersOrRenters: return "Home insurance"
        case .autoInsurance: return "Auto insurance"
        case .vehicles: return "Vehicles"
        }
    }

    /// Empty-state copy: what to do, not what is missing.
    var instruction: String {
        switch self {
        case .emergencyContactFirst: return "Add the person who'd be called first"
        case .emergencyContactSecond: return "Add a second person to call"
        case .preferredHospital: return "Add the hospital you'd want the kids taken to"
        case .homeAddress: return "Add your home address"
        case .keysAndCodes: return "Say where the spare key is, and add any gate or alarm code"
        case .vetOrPetSitter: return "Add who looks after the pets"
        case .healthInsurance: return "Add your health insurance"
        case .pediatrician: return "Add the kids' doctor"
        case .familyDoctor: return "Add your doctor"
        case .pharmacy: return "Add your pharmacy"
        case .dentalInsurance: return "Add dental insurance"
        case .designatedGuardian: return "Name who would care for the kids"
        case .backupGuardian: return "Name a backup"
        case .whereTheWillIs: return "Say where the will is"
        case .attorney: return "Add your attorney"
        case .financialAdvisor: return "Add your financial advisor"
        case .lifeInsurance: return "Add a life insurance policy"
        case .instructionsForKids: return "Write down routines and comfort items"
        case .bankAccounts: return "Add a bank account by name and last 4"
        case .retirementAccounts: return "Add a retirement account"
        case .mortgageOrLandlord: return "Add who the mortgage or rent goes to"
        case .utilities: return "Add a utility account"
        case .recurringBills: return "Add a recurring bill"
        case .passwordManager: return "Say which password manager you use, and where the master password is"
        case .homeownersOrRenters: return "Add home or renters insurance"
        case .autoInsurance: return "Add auto insurance"
        case .vehicles: return "Add a vehicle"
        }
    }

    /// The short nudge shown on the reveal screen and Home ("Next: where is your will?").
    var nudge: String {
        switch self {
        case .whereTheWillIs: return "Next: where is your will?"
        case .designatedGuardian: return "Next: who would care for the kids?"
        case .healthInsurance: return "Next: your health insurance"
        case .emergencyContactFirst: return "Next: who to call first"
        case .bankAccounts: return "Next: where the money is"
        case .homeAddress: return "Next: your home address"
        default: return "Next: \(label.lowercased())"
        }
    }

    static let deepLinkScheme = "petitehome"
    var deepLink: URL { URL(string: "\(Self.deepLinkScheme)://familyfile/\(rawValue)")! }
}

/// A snapshot of what is and isn't filled in. Pure: computed from the models, no side effects.
struct CompletenessReport {
    struct Item: Identifiable {
        let field: FamilyFileField
        let isFilled: Bool
        let weight: Int
        var id: FamilyFileField { field }
    }

    let items: [Item]

    var percent: Int {
        let total = items.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return 0 }
        let filled = items.filter(\.isFilled).reduce(0) { $0 + $1.weight }
        return Int((Double(filled) / Double(total) * 100).rounded())
    }

    /// Highest-value empty fields first, then in Family File order.
    var nextToAdd: [FamilyFileField] {
        items.filter { !$0.isFilled && $0.weight > 0 }
            .sorted { a, b in
                if a.weight != b.weight { return a.weight > b.weight }
                return FamilyFileField.allCases.firstIndex(of: a.field)! < FamilyFileField.allCases.firstIndex(of: b.field)!
            }
            .map(\.field)
    }

    func counts(for section: FamilyFileSection) -> (filled: Int, total: Int) {
        let inSection = items.filter { $0.field.section == section }
        return (inSection.filter(\.isFilled).count, inSection.count)
    }

    func isFilled(_ field: FamilyFileField) -> Bool {
        items.first(where: { $0.field == field })?.isFilled ?? false
    }

    /// Analytics bucket: 0–25, 26–50, 51–75, 76–99, 100.
    var bucket: String {
        switch percent {
        case 100: return "100"
        case 76...99: return "76-99"
        case 51...75: return "51-75"
        case 26...50: return "26-50"
        default: return "0-25"
        }
    }
}

enum Completeness {
    static func report(file: FamilyFile?, household: Household?) -> CompletenessReport {
        report(file: file, childPediatricians: (household?.kids ?? []).map(\.pediatrician))
    }

    /// The core scorer. `childPediatricians` is one entry per child (nil when that child has no doctor yet).
    static func report(file: FamilyFile?, childPediatricians: [Contact?]) -> CompletenessReport {
        let hasChildren = !childPediatricians.isEmpty
        let hasVehicles = !(file?.vehicles.isEmpty ?? true) || (file?.autoInsurance?.isFilled ?? false)

        func filled(_ field: FamilyFileField) -> Bool {
            guard let f = file else { return false }
            switch field {
            case .emergencyContactFirst: return f.emergencyContacts.first?.isFilled ?? false
            case .emergencyContactSecond: return f.emergencyContacts.count >= 2 && f.emergencyContacts[1].isFilled
            case .preferredHospital: return f.preferredHospital?.isFilled ?? false
            case .homeAddress: return !f.homeAddress.trimmingCharacters(in: .whitespaces).isEmpty
            case .keysAndCodes: return !f.spareKeyLocation.isEmpty || f.hasGateCode || f.hasAlarmCode
            case .vetOrPetSitter: return f.vetOrPetSitter?.isFilled ?? false
            case .healthInsurance: return f.healthInsurance.isFilled
            case .pediatrician: return hasChildren && childPediatricians.allSatisfy { $0?.isFilled ?? false }
            case .familyDoctor: return f.familyDoctor?.isFilled ?? false
            case .pharmacy: return f.pharmacy?.isFilled ?? false
            case .dentalInsurance: return f.dentalInsurance?.isFilled ?? false
            case .designatedGuardian: return f.designatedGuardian?.isFilled ?? false
            case .backupGuardian: return f.backupGuardian?.isFilled ?? false
            case .whereTheWillIs: return !f.whereTheWillIs.trimmingCharacters(in: .whitespaces).isEmpty
            case .attorney: return f.attorney?.isFilled ?? false
            case .financialAdvisor: return f.financialAdvisor?.isFilled ?? false
            case .lifeInsurance: return f.lifeInsurance.contains { $0.isFilled }
            case .instructionsForKids: return !f.instructionsForKids.trimmingCharacters(in: .whitespaces).isEmpty
            case .bankAccounts: return f.bankAccounts.contains { $0.isFilled }
            case .retirementAccounts: return f.retirementAccounts.contains { $0.isFilled }
            case .mortgageOrLandlord: return f.mortgageOrLandlord?.isFilled ?? false
            case .utilities: return f.utilities.contains { $0.isFilled }
            case .recurringBills: return f.recurringBills.contains { $0.isFilled }
            case .passwordManager: return !f.passwordManager.trimmingCharacters(in: .whitespaces).isEmpty
            case .homeownersOrRenters: return f.homeownersOrRenters?.isFilled ?? false
            case .autoInsurance: return f.autoInsurance?.isFilled ?? false
            case .vehicles: return f.vehicles.contains { $0.isFilled }
            }
        }

        func weight(_ field: FamilyFileField) -> Int {
            switch field {
            case .pediatrician, .designatedGuardian, .backupGuardian, .instructionsForKids:
                // Only meaningful when there are children in the household.
                return hasChildren ? field.weight : 0
            case .autoInsurance:
                // Counts once the household has said it has a car.
                return hasVehicles ? field.weight : 0
            default:
                return field.weight
            }
        }

        let items = FamilyFileField.allCases.map {
            CompletenessReport.Item(field: $0, isFilled: filled($0), weight: weight($0))
        }
        return CompletenessReport(items: items)
    }
}
