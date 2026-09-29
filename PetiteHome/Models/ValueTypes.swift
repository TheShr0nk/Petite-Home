import Foundation

// Value types stored inside SwiftData models as Codable attributes.
// Rule: the app never stores passwords, PINs, or full account numbers. The
// field names make that obvious.

struct Contact: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var relationship: String = ""
    var phone: String = ""
    var email: String = ""
    var address: String = ""
    var notes: String = ""

    var isFilled: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    var summary: String {
        guard isFilled else { return "" }
        var parts = [name]
        if !relationship.isEmpty { parts.append(relationship) }
        if !phone.isEmpty { parts.append(phone) }
        return parts.joined(separator: " · ")
    }
}

struct InsurancePolicy: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var carrier: String = ""
    /// The member or policy ID printed on the card. Not a credential.
    var policyOrMemberID: String = ""
    var groupNumber: String = ""
    var phone: String = ""
    var notes: String = ""
    /// Optional renewal or expiry date; drives Premium expiration reminders.
    var expiresOn: Date? = nil
    var remindersEnabled: Bool = true

    var isFilled: Bool { !carrier.trimmingCharacters(in: .whitespaces).isEmpty }
    var summary: String {
        guard isFilled else { return "" }
        var parts = [carrier]
        if !policyOrMemberID.isEmpty { parts.append("ID \(policyOrMemberID)") }
        return parts.joined(separator: " · ")
    }
}

struct AccountReference: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var institution: String = ""
    var nickname: String = ""
    var ownerNames: String = ""
    /// Last 4 only. Never the full number.
    var lastFour: String = ""
    var notes: String = ""

    var isFilled: Bool { !institution.trimmingCharacters(in: .whitespaces).isEmpty }
    var summary: String {
        var parts = [institution]
        if !nickname.isEmpty { parts.append(nickname) }
        if !lastFour.isEmpty { parts.append("…\(lastFour)") }
        return parts.joined(separator: " · ")
    }
}

struct Vehicle: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var yearMakeModel: String = ""
    var plate: String = ""
    var titleLocation: String = ""
    var loanServicer: String = ""
    /// Registration renewal; drives Premium expiration reminders.
    var registrationExpiresOn: Date? = nil
    var remindersEnabled: Bool = true

    var isFilled: Bool { !yearMakeModel.trimmingCharacters(in: .whitespaces).isEmpty }
}

struct Medication: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var dose: String = ""
    var schedule: String = ""
    var notes: String = ""
}

/// A dated size entry. Free keeps only the latest; Premium keeps the history.
struct SizeRecord: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var clothing: String = ""
    var shoe: String = ""
    var diaper: String = ""
    var recordedAt: Date = Date()
}

/// A dated item on the Family File that can expire: passport, licence, car seat.
struct ExpiringItem: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var expiresOn: Date = Date()
    var remindersEnabled: Bool = false
    /// Optional link to a person by id.
    var personID: UUID? = nil
}

enum AdultRole: String, Codable, CaseIterable {
    case parent, guardian
    var label: String { self == .parent ? "Parent" : "Guardian" }
}

enum TaskCategory: String, Codable, CaseIterable, Identifiable {
    case home, car, kids, finance, health, pets
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var systemImage: String {
        switch self {
        case .home: return "house"
        case .car: return "car"
        case .kids: return "figure.and.child.holdinghands"
        case .finance: return "banknote"
        case .health: return "heart.text.square"
        case .pets: return "pawprint"
        }
    }
}

enum Recurrence: Codable, Hashable {
    case none, weekly, monthly, quarterly, semiannual, annual
    case custom(days: Int)

    var label: String {
        switch self {
        case .none: return "Once"
        case .weekly: return "Every week"
        case .monthly: return "Every month"
        case .quarterly: return "Every 3 months"
        case .semiannual: return "Every 6 months"
        case .annual: return "Every year"
        case .custom(let days): return "Every \(days) days"
        }
    }

    /// The due date after `date` for this recurrence, or nil when the task does not repeat.
    func next(after date: Date, calendar: Calendar = .current) -> Date? {
        switch self {
        case .none: return nil
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date)
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date)
        case .quarterly: return calendar.date(byAdding: .month, value: 3, to: date)
        case .semiannual: return calendar.date(byAdding: .month, value: 6, to: date)
        case .annual: return calendar.date(byAdding: .year, value: 1, to: date)
        case .custom(let days): return calendar.date(byAdding: .day, value: max(days, 1), to: date)
        }
    }

    // Stored in the model as a string plus an interval, so CloudKit sees two plain attributes.
    var storageKey: String {
        switch self {
        case .none: return "none"
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .quarterly: return "quarterly"
        case .semiannual: return "semiannual"
        case .annual: return "annual"
        case .custom: return "custom"
        }
    }
    var storageDays: Int {
        if case .custom(let days) = self { return days }
        return 0
    }
    static func from(key: String, days: Int) -> Recurrence {
        switch key {
        case "weekly": return .weekly
        case "monthly": return .monthly
        case "quarterly": return .quarterly
        case "semiannual": return .semiannual
        case "annual": return .annual
        case "custom": return .custom(days: max(days, 1))
        default: return .none
        }
    }
    static let presets: [Recurrence] = [.none, .weekly, .monthly, .quarterly, .semiannual, .annual]
}

enum VaultCategory: String, Codable, CaseIterable, Identifiable {
    case birthCert, ssnCard, passport, insuranceCard, immunization, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .birthCert: return "Birth certificate"
        case .ssnCard: return "Social Security card"
        case .passport: return "Passport"
        case .insuranceCard: return "Insurance card"
        case .immunization: return "Immunization record"
        case .other: return "Other"
        }
    }
    var systemImage: String {
        switch self {
        case .birthCert: return "doc.text"
        case .ssnCard: return "person.text.rectangle"
        case .passport: return "airplane"
        case .insuranceCard: return "cross.case"
        case .immunization: return "syringe"
        case .other: return "doc"
        }
    }
    /// Passports expire. Most of the rest do not.
    var usuallyExpires: Bool { self == .passport || self == .insuranceCard }
}

enum TrustedAccessLevel: String, Codable, CaseIterable {
    case viewFamilyFile, viewFamilyFileAndVault
    var label: String {
        switch self {
        case .viewFamilyFile: return "Family File only"
        case .viewFamilyFileAndVault: return "Family File and vault"
        }
    }
}

/// The youngest-child segment. Same buckets as the website's signup question
/// so Klaviyo profiles line up: Expecting | Under 1 | 1–4 | 5+
enum AgeSegment: String, Codable, CaseIterable {
    case expecting = "Expecting"
    case underOne = "Under 1"
    case oneToFour = "1–4"
    case fivePlus = "5+"

    static func forYoungest(birthdates: [Date], expecting: Bool, now: Date = Date(), calendar: Calendar = .current) -> AgeSegment? {
        let born = birthdates.filter { $0 <= now }
        if let youngest = born.max() {
            let years = calendar.dateComponents([.year], from: youngest, to: now).year ?? 0
            if years < 1 { return .underOne }
            if years < 5 { return .oneToFour }
            return .fivePlus
        }
        if expecting || birthdates.contains(where: { $0 > now }) { return .expecting }
        return nil
    }
}

enum AgeFormatter {
    /// "14 mo", "3 yr", "6 wk", "due" for a future date.
    static func short(from birthdate: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        if birthdate > now { return "due" }
        let c = calendar.dateComponents([.year, .month, .day], from: birthdate, to: now)
        let years = c.year ?? 0, months = c.month ?? 0, days = c.day ?? 0
        if years >= 2 { return "\(years) yr" }
        let totalMonths = years * 12 + months
        if totalMonths >= 1 { return "\(totalMonths) mo" }
        let weeks = days / 7
        if weeks >= 1 { return "\(weeks) wk" }
        return "\(max(days, 0)) d"
    }
}
