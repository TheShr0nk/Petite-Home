import Foundation

/// The template pack a user can enable in one tap on the Tasks tab.
struct TaskTemplate: Identifiable, Hashable {
    let key: String
    let title: String
    let recurrence: Recurrence
    let category: TaskCategory
    let notes: String
    /// Hour the reminder fires.
    var hour: Int = 9
    /// Weekday (1 = Sunday) for weekly templates that belong on a particular day.
    var weekday: Int? = nil
    /// Whether the template starts selected in onboarding.
    var onByDefault: Bool = true
    var id: String { key }

    var cadence: Cadence { recurrence.cadence }

    static let pack: [TaskTemplate] = [
        // Daily: the small shared rhythm. Mid-afternoon so there's time to defrost something.
        TaskTemplate(key: "plan_dinner", title: "Plan dinner", recurrence: .daily, category: .home, notes: "What's for dinner, who's cooking, and does anything need to come out of the freezer.", hour: 15),
        TaskTemplate(key: "ten_minute_tidy", title: "Ten-minute tidy", recurrence: .daily, category: .home, notes: "Kitchen counters, the floor where the kids were. Ten minutes, then stop.", hour: 19, onByDefault: false),
        // Weekly
        TaskTemplate(key: "plan_week", title: "Plan the week together", recurrence: .weekly, category: .home, notes: "Five minutes on Sunday night: who's where, which nights need a sitter, dinners.", hour: 19, weekday: 1),
        TaskTemplate(key: "grocery_run", title: "Grocery run", recurrence: .weekly, category: .home, notes: "The shopping list in Meals writes itself from the week's recipes.", hour: 9, weekday: 7),
        // Monthly
        TaskTemplate(key: "whats_expiring", title: "Look at what's coming due", recurrence: .monthly, category: .finance, notes: "Passports, insurance, registration. The app lists them on Home.", hour: 9),
        // Seasonal
        TaskTemplate(key: "furnace_filter", title: "Change the furnace filter", recurrence: .quarterly, category: .home, notes: "Write the size on the filter housing so you don't have to look it up."),
        TaskTemplate(key: "smoke_batteries", title: "Replace smoke detector batteries", recurrence: .semiannual, category: .home, notes: "Every detector, including the basement and garage."),
        TaskTemplate(key: "car_registration", title: "Renew car registration", recurrence: .annual, category: .car, notes: ""),
        TaskTemplate(key: "car_seat_straps", title: "Check car seat straps and fit", recurrence: .monthly, category: .kids, notes: "Pinch test at the collarbone. Chest clip at armpit level."),
        TaskTemplate(key: "water_heater", title: "Flush the water heater", recurrence: .semiannual, category: .home, notes: ""),
        TaskTemplate(key: "insurance_review", title: "Review insurance coverage", recurrence: .annual, category: .finance, notes: "Life, home, auto. Has anything changed since last year?"),
    ]

    /// The annual well-child visit, one per kid, anchored to the birthday.
    static func wellChild(for child: Child, calendar: Calendar = .current, now: Date = Date()) -> TaskTemplate {
        TaskTemplate(key: "well_child_\(child.uuid.uuidString)",
                     title: "\(child.displayName)'s well-child visit",
                     recurrence: .annual,
                     category: .health,
                     notes: "Book it around the birthday.")
    }

    /// The first due date for a template: today or tomorrow for daily ones, the named weekday for
    /// weekly ones, the next birthday for well-child visits, otherwise a little way out.
    static func firstDue(for template: TaskTemplate, child: Child? = nil, calendar: Calendar = .current, now: Date = Date()) -> Date {
        if let child, template.key.hasPrefix("well_child_") {
            let dob = calendar.dateComponents([.month, .day], from: child.dateOfBirth)
            var next = calendar.nextDate(after: now, matching: dob, matchingPolicy: .nextTime) ?? now
            if next < now { next = calendar.date(byAdding: .year, value: 1, to: next) ?? next }
            return next
        }
        let today = calendar.startOfDay(for: now)
        switch template.recurrence {
        case .daily:
            let hour = calendar.component(.hour, from: now)
            return hour < template.hour ? today : (calendar.date(byAdding: .day, value: 1, to: today) ?? today)
        case .weekly:
            if let weekday = template.weekday {
                return calendar.nextDate(after: now, matching: DateComponents(weekday: weekday), matchingPolicy: .nextTime) ?? today
            }
            return calendar.date(byAdding: .day, value: 7, to: today) ?? today
        case .monthly: return calendar.date(byAdding: .day, value: 7, to: today) ?? today
        default: return calendar.date(byAdding: .day, value: 30, to: today) ?? today
        }
    }

    func makeTask(due: Date) -> HouseholdTask {
        let task = HouseholdTask(title: title, recurrence: recurrence, nextDue: due, category: category, notes: notes, isFromTemplate: true, templateKey: key)
        task.reminderHour = hour
        return task
    }

    static func grouped() -> [(Cadence, [TaskTemplate])] {
        Cadence.allCases.map { c in (c, pack.filter { $0.cadence == c }) }.filter { !$0.1.isEmpty }
    }
}
