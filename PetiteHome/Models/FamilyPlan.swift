import Foundation
import SwiftData

/// Names the user sees. The area used to be called the Family File; the
/// printable PDF still is, because that's what petitehome.co promises.
enum AppCopy {
    static let binder = "Binder"
    static let binderLower = "binder"
    static let planner = "Planner"
    static let printableTitle = "The Family File"
}

enum PlanKind: String, Codable, CaseIterable, Identifiable {
    case dateNight, outing, trip, appointment, visitors, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dateNight: return "Date night"
        case .outing: return "Outing"
        case .trip: return "Trip"
        case .appointment: return "Appointment"
        case .visitors: return "Visitors"
        case .other: return "Something else"
        }
    }
    var systemImage: String {
        switch self {
        case .dateNight: return "moon.stars"
        case .outing: return "figure.and.child.holdinghands"
        case .trip: return "suitcase"
        case .appointment: return "stethoscope"
        case .visitors: return "house.and.flag"
        case .other: return "sparkles"
        }
    }
    /// Which kinds usually mean the kids need someone.
    var usuallyNeedsSitter: Bool { self == .dateNight || self == .appointment }
}

enum SitterStatus: String, Codable, CaseIterable, Identifiable {
    case notNeeded, needed, asked, confirmed
    var id: String { rawValue }
    var label: String {
        switch self {
        case .notNeeded: return "Kids come along"
        case .needed: return "Need a sitter"
        case .asked: return "Asked"
        case .confirmed: return "Confirmed"
        }
    }
}

/// Someone who has looked after the kids. Lives on the household as a value list.
struct SitterProfile: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var contact: Contact = Contact()
    /// "$20/hr", "grandma, free, needs a heads up"
    var rateNotes: String = ""
    var notes: String = ""
    var lastUsedAt: Date? = nil
    var timesUsed: Int = 0
    var name: String { contact.name }
}

/// A plan the two of you make: date night, a day out, a trip, a visit.
@Model
final class FamilyPlan {
    /// The stored UUID is the Identifiable id, not SwiftData's PersistentIdentifier.
    typealias ID = UUID
    var id: UUID = UUID()
    var title: String = ""
    var kindRaw: String = PlanKind.dateNight.rawValue
    var startDate: Date = Date()
    var endDate: Date? = nil
    var location: String = ""
    var notes: String = ""
    var adultIDs: [UUID] = []
    var childIDs: [UUID] = []
    var sitterID: UUID? = nil
    var sitterStatusRaw: String = SitterStatus.notNeeded.rawValue
    var reminderEnabled: Bool = true
    var createdAt: Date = Date()

    var household: Household? = nil

    init(title: String, kind: PlanKind, startDate: Date) {
        self.title = title
        self.kindRaw = kind.rawValue
        self.startDate = startDate
        self.sitterStatusRaw = (kind.usuallyNeedsSitter ? SitterStatus.needed : .notNeeded).rawValue
    }

    var kind: PlanKind {
        get { PlanKind(rawValue: kindRaw) ?? .other }
        set { kindRaw = newValue.rawValue }
    }
    var sitterStatus: SitterStatus {
        get { SitterStatus(rawValue: sitterStatusRaw) ?? .notNeeded }
        set { sitterStatusRaw = newValue.rawValue }
    }
    var displayTitle: String { title.isEmpty ? kind.label : title }
    var isPast: Bool { (endDate ?? startDate) < Date() }
    var needsAttention: Bool { !isPast && (sitterStatus == .needed || sitterStatus == .asked) }
}

/// Finds evenings in the next stretch where neither partner has anything on
/// after the cut-off hour. Pure, so the tests can pin it down.
enum FreeEveningFinder {
    struct Evening: Identifiable, Hashable {
        let date: Date
        var id: Date { date }
    }

    static func find(events: [CalendarEvent], plans: [FamilyPlan], from start: Date = Date(), days: Int = 14,
                     eveningStartsAt hour: Int = 18, weekendsFirst: Bool = true, calendar: Calendar = .current) -> [Evening] {
        let startOfFirst = calendar.startOfDay(for: start)
        var out: [Evening] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfFirst),
                  let eveningStart = calendar.date(byAdding: .hour, value: hour, to: day),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { continue }
            if eveningStart < start { continue } // tonight only counts if the evening hasn't started
            let busy = events.contains { $0.startDate < dayEnd && $0.endDate > eveningStart && !$0.isAllDay }
                || plans.contains { calendar.isDate($0.startDate, inSameDayAs: day) }
            if !busy { out.append(Evening(date: eveningStart)) }
        }
        if weekendsFirst {
            out.sort { a, b in
                let wa = calendar.isDateInWeekend(a.date), wb = calendar.isDateInWeekend(b.date)
                if wa != wb { return wa }
                return a.date < b.date
            }
        }
        return out
    }
}

/// The text that goes to the sitter: when, where the parents are, and the
/// things from the Binder a sitter needs. Never codes, never account details.
enum SitterSheet {
    static func text(plan: FamilyPlan, household: Household, sitterName: String) -> String {
        let file = household.familyFile
        var lines: [String] = []
        let who = sitterName.isEmpty ? "Hi" : "Hi \(sitterName.split(separator: " ").first.map(String.init) ?? sitterName)"
        lines.append("\(who), here's everything for \(plan.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).")
        var when = "We'll be out from \(plan.startDate.formatted(date: .omitted, time: .shortened))"
        if let end = plan.endDate { when += " to \(end.formatted(date: .omitted, time: .shortened))" }
        if !plan.location.isEmpty { when += ", at \(plan.location)" }
        lines.append(when + ".")
        lines.append("")
        let kids = household.kids.filter { plan.childIDs.isEmpty || plan.childIDs.contains($0.id) }
        for child in kids {
            var parts = ["\(child.displayName), \(child.ageShort)"]
            if !child.allergies.isEmpty { parts.append("Allergies: \(child.allergies.joined(separator: ", "))") }
            if !child.medications.isEmpty { parts.append("Meds: \(child.medications.map { "\($0.name) \($0.dose) \($0.schedule)".trimmingCharacters(in: .whitespaces) }.joined(separator: "; "))") }
            if !child.notes.isEmpty { parts.append(child.notes) }
            lines.append(parts.joined(separator: ". "))
        }
        if let instructions = file?.instructionsForKids, !instructions.isEmpty {
            lines.append("")
            lines.append(instructions)
        }
        lines.append("")
        lines.append("If you can't reach us:")
        for adult in household.adults where !adult.phone.isEmpty { lines.append("\(adult.displayName): \(adult.phone)") }
        for contact in (file?.emergencyContacts ?? []).prefix(2) where contact.isFilled { lines.append("\(contact.name)\(contact.relationship.isEmpty ? "" : " (\(contact.relationship))"): \(contact.phone)") }
        if let doc = kids.first?.pediatrician, doc.isFilled { lines.append("Pediatrician: \(doc.name) \(doc.phone)") }
        if let hospital = file?.preferredHospital, hospital.isFilled { lines.append("Hospital: \(hospital.name)") }
        if let address = file?.homeAddress, !address.isEmpty { lines.append("Our address: \(address)") }
        lines.append("")
        lines.append("Thank you.")
        return lines.joined(separator: "\n")
    }

    /// The short ask, for the first text.
    static func askText(plan: FamilyPlan, sitterName: String) -> String {
        let first = sitterName.split(separator: " ").first.map(String.init) ?? sitterName
        var s = "Hi \(first), any chance you're free \(plan.startDate.formatted(.dateTime.weekday(.wide))) \(plan.startDate.formatted(.dateTime.month(.abbreviated).day())) from \(plan.startDate.formatted(date: .omitted, time: .shortened))"
        if let end = plan.endDate { s += " to \(end.formatted(date: .omitted, time: .shortened))" }
        s += " to watch the kids?"
        return s
    }
}
