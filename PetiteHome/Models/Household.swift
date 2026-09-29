import Foundation
import SwiftData

@Model
final class Household {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()
    /// Set once the household's file has been saved (after Sign in with Apple).
    var ownerAppleUserID: String? = nil
    /// The youngest-child segment captured at onboarding, for the Klaviyo handoff.
    var youngestChildSegmentRaw: String? = nil
    /// True while the parents are expecting and no child is born yet.
    var isExpecting: Bool = false
    /// Screen 6 skipped with "I haven't decided yet".
    var guardianUndecided: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \Adult.household) var members: [Adult]? = []
    @Relationship(deleteRule: .cascade, inverse: \Child.household) var children: [Child]? = []
    @Relationship(deleteRule: .cascade, inverse: \FamilyFile.household) var familyFile: FamilyFile? = nil
    @Relationship(deleteRule: .cascade, inverse: \HouseholdTask.household) var tasks: [HouseholdTask]? = []
    @Relationship(deleteRule: .cascade, inverse: \VaultDocument.household) var documents: [VaultDocument]? = []
    @Relationship(deleteRule: .cascade, inverse: \TrustedContact.household) var trustedContacts: [TrustedContact]? = []
    @Relationship(deleteRule: .cascade, inverse: \CalendarEvent.household) var calendarEvents: [CalendarEvent]? = []
    @Relationship(deleteRule: .cascade, inverse: \Recipe.household) var recipes: [Recipe]? = []
    @Relationship(deleteRule: .cascade, inverse: \PlannedMeal.household) var meals: [PlannedMeal]? = []
    @Relationship(deleteRule: .cascade, inverse: \FamilyPlan.household) var plans: [FamilyPlan]? = []
    /// People who have watched the kids. Shared with the partner.
    var sitters: [SitterProfile] = []
    /// Shopping list lines checked off, by normalized ingredient key. Shared with the partner.
    var groceryChecked: [String] = []

    init(name: String = "") {
        self.name = name
    }

    var youngestChildSegment: AgeSegment? {
        get { youngestChildSegmentRaw.flatMap(AgeSegment.init(rawValue:)) }
        set { youngestChildSegmentRaw = newValue?.rawValue }
    }

    var adults: [Adult] { (members ?? []).sorted { $0.isAccountOwner && !$1.isAccountOwner } }
    var kids: [Child] { (children ?? []).sorted { $0.dateOfBirth > $1.dateOfBirth } }
    var owner: Adult? { adults.first(where: { $0.isAccountOwner }) }
    var partner: Adult? { adults.first(where: { !$0.isAccountOwner }) }
    var youngestChild: Child? { kids.first }

    var displayName: String {
        if !name.isEmpty { return name }
        if let last = owner?.lastName, !last.isEmpty { return "The \(last) family" }
        return "Our household"
    }
}

@Model
final class Adult {
    var id: UUID = UUID()
    var firstName: String = ""
    var lastName: String = ""
    var phone: String = ""
    var email: String = ""
    var dateOfBirth: Date? = nil
    var employer: String = ""
    var workPhone: String = ""
    var roleRaw: String = AdultRole.parent.rawValue
    var isAccountOwner: Bool = false
    /// Life Sync: whether this adult has turned on calendar mirroring on their phone, and when it last ran.
    var calendarSyncEnabled: Bool = false
    var calendarSyncedAt: Date? = nil
    /// Adult-owned expiring items (driver's licence, passport).
    var expiringItems: [ExpiringItem] = []

    var household: Household? = nil

    init(firstName: String, lastName: String = "", role: AdultRole = .parent, isAccountOwner: Bool = false) {
        self.firstName = firstName
        self.lastName = lastName
        self.roleRaw = role.rawValue
        self.isAccountOwner = isAccountOwner
    }

    var role: AdultRole {
        get { AdultRole(rawValue: roleRaw) ?? .parent }
        set { roleRaw = newValue.rawValue }
    }
    var fullName: String { [firstName, lastName].filter { !$0.isEmpty }.joined(separator: " ") }
    var displayName: String { firstName.isEmpty ? "Adult" : firstName }
}

@Model
final class Child {
    var id: UUID = UUID()
    var firstName: String = ""
    var dateOfBirth: Date = Date()
    var pediatrician: Contact? = nil
    var allergies: [String] = []
    var medications: [Medication] = []
    var bloodType: String? = nil
    var clothingSize: String? = nil
    var shoeSize: String? = nil
    var diaperSize: String? = nil
    var sizeUpdatedAt: Date = Date()
    /// Premium: dated size history. Free tier keeps only the current values above.
    var sizeHistory: [SizeRecord] = []
    var school: Contact? = nil
    var notes: String = ""
    /// Child-owned expiring items (passport, car seat).
    var expiringItems: [ExpiringItem] = []

    var household: Household? = nil

    init(firstName: String, dateOfBirth: Date) {
        self.firstName = firstName
        self.dateOfBirth = dateOfBirth
    }

    var displayName: String { firstName.isEmpty ? "Child" : firstName }
    var ageShort: String { AgeFormatter.short(from: dateOfBirth) }
    var initial: String { String(firstName.prefix(1)) }

    /// Records the current sizes as a dated history entry (Premium keeps them; free overwrites).
    func updateSizes(clothing: String?, shoe: String?, diaper: String?, keepHistory: Bool) {
        clothingSize = clothing
        shoeSize = shoe
        diaperSize = diaper
        sizeUpdatedAt = Date()
        if keepHistory {
            sizeHistory.append(SizeRecord(clothing: clothing ?? "", shoe: shoe ?? "", diaper: diaper ?? "", recordedAt: Date()))
        }
    }
}

@Model
final class FamilyFile {
    var id: UUID = UUID()

    // Section 1 — In an emergency
    var emergencyContacts: [Contact] = []
    var preferredHospital: Contact? = nil
    var vetOrPetSitter: Contact? = nil
    var homeAddress: String = ""
    /// Gate and alarm codes live in the Keychain, encrypted. These flags only say whether one is set.
    var hasGateCode: Bool = false
    var hasAlarmCode: Bool = false
    var spareKeyLocation: String = ""

    // Section 2 — Medical
    var healthInsurance: InsurancePolicy = InsurancePolicy()
    var dentalInsurance: InsurancePolicy? = nil
    var familyDoctor: Contact? = nil
    var pharmacy: Contact? = nil

    // Section 3 — If something happens to us
    var designatedGuardian: Contact? = nil
    var backupGuardian: Contact? = nil
    var whereTheWillIs: String = ""
    var attorney: Contact? = nil
    var financialAdvisor: Contact? = nil
    var lifeInsurance: [InsurancePolicy] = []
    var instructionsForKids: String = ""

    // Section 4 — Accounts & money (names + where, never credentials)
    var bankAccounts: [AccountReference] = []
    var retirementAccounts: [AccountReference] = []
    var mortgageOrLandlord: Contact? = nil
    var utilities: [AccountReference] = []
    var recurringBills: [AccountReference] = []
    var passwordManager: String = ""

    // Section 5 — Home & vehicles
    var homeownersOrRenters: InsurancePolicy? = nil
    var autoInsurance: InsurancePolicy? = nil
    var vehicles: [Vehicle] = []

    var updatedAt: Date = Date()

    var household: Household? = nil

    init() {}
}

@Model
final class HouseholdTask {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var recurrenceKey: String = Recurrence.none.storageKey
    var customIntervalDays: Int = 0
    var nextDue: Date = Date()
    var categoryRaw: String = TaskCategory.home.rawValue
    var completions: [Date] = []
    var isFromTemplate: Bool = false
    var templateKey: String? = nil
    var createdAt: Date = Date()

    var assignedTo: Adult? = nil
    var household: Household? = nil

    init(title: String, recurrence: Recurrence, nextDue: Date, category: TaskCategory, notes: String = "", isFromTemplate: Bool = false, templateKey: String? = nil) {
        self.title = title
        self.recurrenceKey = recurrence.storageKey
        self.customIntervalDays = recurrence.storageDays
        self.nextDue = nextDue
        self.categoryRaw = category.rawValue
        self.notes = notes
        self.isFromTemplate = isFromTemplate
        self.templateKey = templateKey
    }

    var recurrence: Recurrence {
        get { Recurrence.from(key: recurrenceKey, days: customIntervalDays) }
        set { recurrenceKey = newValue.storageKey; customIntervalDays = newValue.storageDays }
    }
    var category: TaskCategory {
        get { TaskCategory(rawValue: categoryRaw) ?? .home }
        set { categoryRaw = newValue.rawValue }
    }
    var isOverdue: Bool { nextDue < Calendar.current.startOfDay(for: Date()) }
    var isDone: Bool { recurrence.storageKey == "none" && !completions.isEmpty }

    /// Marks the task complete. Repeating tasks roll forward; one-off tasks stay done.
    func complete(on date: Date = Date()) {
        completions.append(date)
        if let next = recurrence.next(after: max(nextDue, date)) {
            nextDue = next
        }
    }
}

@Model
final class VaultDocument {
    var id: UUID = UUID()
    var title: String = ""
    var categoryRaw: String = VaultCategory.other.rawValue
    /// AES-GCM sealed box (nonce + ciphertext + tag), sealed client-side before it syncs.
    /// External storage means CloudKit carries it as a CKAsset.
    @Attribute(.externalStorage) var encryptedAsset: Data? = nil
    /// "image/jpeg" or "application/pdf".
    var mimeType: String = "image/jpeg"
    var expiresOn: Date? = nil
    var remindersEnabled: Bool = false
    var addedAt: Date = Date()
    /// Which key wrapped the asset, so a rotated key can still open old documents.
    var keyIdentifier: String = ""

    var linkedChild: Child? = nil
    var linkedAdult: Adult? = nil
    var household: Household? = nil

    init(title: String, category: VaultCategory) {
        self.title = title
        self.categoryRaw = category.rawValue
    }

    var category: VaultCategory {
        get { VaultCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    var linkedName: String? { linkedChild?.displayName ?? linkedAdult?.displayName }
}

@Model
final class TrustedContact {
    var id: UUID = UUID()
    var contact: Contact = Contact()
    var accessLevelRaw: String = TrustedAccessLevel.viewFamilyFile.rawValue
    var shareLink: URL? = nil
    /// The CloudKit record name of the shared snapshot, so it can be revoked.
    var shareRecordName: String? = nil
    var expiresAt: Date? = nil
    var createdAt: Date = Date()

    var household: Household? = nil

    init(contact: Contact, accessLevel: TrustedAccessLevel, expiresAt: Date?) {
        self.contact = contact
        self.accessLevelRaw = accessLevel.rawValue
        self.expiresAt = expiresAt
    }

    var accessLevel: TrustedAccessLevel {
        get { TrustedAccessLevel(rawValue: accessLevelRaw) ?? .viewFamilyFile }
        set { accessLevelRaw = newValue.rawValue }
    }
    var isExpired: Bool { (expiresAt ?? .distantFuture) < Date() }
}

enum PetiteSchema {
    static let models: [any PersistentModel.Type] = [
        Household.self, Adult.self, Child.self, FamilyFile.self,
        HouseholdTask.self, VaultDocument.self, TrustedContact.self, CalendarEvent.self,
        Recipe.self, PlannedMeal.self, FamilyPlan.self,
    ]
}
