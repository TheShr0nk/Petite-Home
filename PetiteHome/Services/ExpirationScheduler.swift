import Foundation

/// One dated thing that can expire, wherever it lives in the model.
struct Expiration: Identifiable, Hashable {
    let id: UUID
    let title: String
    let date: Date
    let remindersEnabled: Bool
    var daysLeft: Int { Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: date)).day ?? 0 }
    var isOverdue: Bool { daysLeft < 0 }
    var isSoon: Bool { daysLeft >= 0 && daysLeft <= 60 }
}

/// Walks everything with a date and keeps local notifications in step with it.
/// Reminders are premium: when the subscription lapses they are cancelled.
enum ExpirationScheduler {
    static func expirations(for household: Household) -> [Expiration] {
        var out: [Expiration] = []
        if let file = household.familyFile {
            if let d = file.healthInsurance.expiresOn { out.append(Expiration(id: file.uuid, title: "Health insurance renewal", date: d, remindersEnabled: file.healthInsurance.remindersEnabled)) }
            if let dental = file.dentalInsurance, let d = dental.expiresOn { out.append(Expiration(id: stable(file.uuid, "dental"), title: "Dental insurance renewal", date: d, remindersEnabled: dental.remindersEnabled)) }
            if let home = file.homeownersOrRenters, let d = home.expiresOn { out.append(Expiration(id: stable(file.uuid, "home"), title: "Home insurance renewal", date: d, remindersEnabled: home.remindersEnabled)) }
            if let auto = file.autoInsurance, let d = auto.expiresOn { out.append(Expiration(id: stable(file.uuid, "auto"), title: "Auto insurance renewal", date: d, remindersEnabled: auto.remindersEnabled)) }
            for v in file.vehicles { if let d = v.registrationExpiresOn { out.append(Expiration(id: v.id, title: "\(v.yearMakeModel) registration", date: d, remindersEnabled: v.remindersEnabled)) } }
        }
        for adult in household.adults {
            for item in adult.expiringItems { out.append(Expiration(id: item.id, title: "\(adult.displayName)'s \(item.title.lowercased())", date: item.expiresOn, remindersEnabled: item.remindersEnabled)) }
        }
        for child in household.kids {
            for item in child.expiringItems { out.append(Expiration(id: item.id, title: "\(child.displayName)'s \(item.title.lowercased())", date: item.expiresOn, remindersEnabled: item.remindersEnabled)) }
        }
        for doc in household.documents ?? [] {
            if let d = doc.expiresOn { out.append(Expiration(id: doc.uuid, title: doc.title, date: d, remindersEnabled: doc.remindersEnabled)) }
        }
        return out.sorted { $0.date < $1.date }
    }

    static func upcoming(for household: Household, limit: Int = 3) -> [Expiration] {
        Array(expirations(for: household).filter { !$0.isOverdue || $0.daysLeft > -30 }.prefix(limit))
    }

    /// Re-schedules every enabled reminder (premium) or cancels them all (free).
    static func sync(household: Household, isPremium: Bool) {
        let service = NotificationService.shared
        for exp in expirations(for: household) {
            if isPremium && exp.remindersEnabled {
                service.scheduleExpiration(id: exp.id, title: exp.title, expiresOn: exp.date)
            } else {
                service.cancelExpiration(id: exp.id)
            }
        }
        for task in household.tasks ?? [] {
            if isPremium && !task.isDone {
                service.scheduleTaskDue(id: task.uuid, title: task.title, due: task.nextDue, hour: task.reminderHour)
            } else {
                service.cancelTaskDue(id: task.uuid)
            }
        }
    }

    /// A deterministic UUID for sub-items that have no id of their own.
    private static func stable(_ base: UUID, _ salt: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let src = Array(base.uuidString.utf8) + Array(salt.utf8)
        for (i, b) in src.enumerated() { bytes[i % 16] ^= b }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
