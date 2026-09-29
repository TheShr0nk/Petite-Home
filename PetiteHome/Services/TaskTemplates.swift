import Foundation

/// The template pack a user can enable in one tap on the Tasks tab.
struct TaskTemplate: Identifiable, Hashable {
    let key: String
    let title: String
    let recurrence: Recurrence
    let category: TaskCategory
    let notes: String
    var id: String { key }

    static let pack: [TaskTemplate] = [
        TaskTemplate(key: "furnace_filter", title: "Change the furnace filter", recurrence: .quarterly, category: .home, notes: "Write the size on the filter housing so you don't have to look it up."),
        TaskTemplate(key: "smoke_batteries", title: "Replace smoke detector batteries", recurrence: .semiannual, category: .home, notes: "Every detector, including the basement and garage."),
        TaskTemplate(key: "car_registration", title: "Renew car registration", recurrence: .annual, category: .car, notes: ""),
        TaskTemplate(key: "car_seat_straps", title: "Check car seat straps and fit", recurrence: .monthly, category: .kids, notes: "Pinch test at the collarbone. Chest clip at armpit level."),
        TaskTemplate(key: "water_heater", title: "Flush the water heater", recurrence: .semiannual, category: .home, notes: ""),
        TaskTemplate(key: "insurance_review", title: "Review insurance coverage", recurrence: .annual, category: .finance, notes: "Life, home, auto. Has anything changed since last year?"),
    ]

    /// The annual well-child visit, one per kid, anchored to the birthday.
    static func wellChild(for child: Child, calendar: Calendar = .current, now: Date = Date()) -> TaskTemplate {
        TaskTemplate(key: "well_child_\(child.id.uuidString)",
                     title: "\(child.displayName)'s well-child visit",
                     recurrence: .annual,
                     category: .health,
                     notes: "Book it around the birthday.")
    }

    /// The first due date for a template: the next birthday for well-child visits, otherwise one interval out.
    static func firstDue(for template: TaskTemplate, child: Child? = nil, calendar: Calendar = .current, now: Date = Date()) -> Date {
        if let child, template.key.hasPrefix("well_child_") {
            let dob = calendar.dateComponents([.month, .day], from: child.dateOfBirth)
            var next = calendar.nextDate(after: now, matching: dob, matchingPolicy: .nextTime) ?? now
            if next < now { next = calendar.date(byAdding: .year, value: 1, to: next) ?? next }
            return next
        }
        switch template.recurrence {
        case .monthly: return calendar.date(byAdding: .day, value: 7, to: now) ?? now
        default: return calendar.date(byAdding: .day, value: 30, to: now) ?? now
        }
    }

    func makeTask(due: Date) -> HouseholdTask {
        HouseholdTask(title: title, recurrence: recurrence, nextDue: due, category: category, notes: notes, isFromTemplate: true, templateKey: key)
    }
}
