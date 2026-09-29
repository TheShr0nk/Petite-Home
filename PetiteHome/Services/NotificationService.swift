import Foundation
import UserNotifications

/// All notifications are local. Three categories: Family File nudges (weekly
/// max, stop at 80%), expirations (premium) and tasks due (premium).
/// Permission is requested only when the user first enables a reminder or
/// taps the nudge card, never during onboarding.
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    enum Category: String { case nudge, expiration, task }

    private let nudgeID = "familyfile.nudge"
    private let lastNudgeKey = "notifications.lastNudgeAt"
    private let firstOpenKey = "notifications.firstOpenAfterOnboarding"

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: Family File nudge

    /// Called on each app open. First fires 24h after onboarding, then weekly at most, stopping at 80%.
    func scheduleNudgeIfNeeded(percent: Int, next: FamilyFileField?) {
        let defaults = UserDefaults.standard
        guard percent < 80, let next else {
            center.removePendingNotificationRequests(withIdentifiers: [nudgeID])
            return
        }
        if defaults.object(forKey: firstOpenKey) == nil {
            defaults.set(Date(), forKey: firstOpenKey)
        }
        let lastScheduled = defaults.object(forKey: lastNudgeKey) as? Date
        // One is already waiting to fire; leave it alone.
        if let lastScheduled, lastScheduled > Date() { return }
        let anchor = lastScheduled ?? (defaults.object(forKey: firstOpenKey) as? Date) ?? Date()
        let interval: TimeInterval = lastScheduled == nil ? 24 * 3600 : 7 * 24 * 3600
        let fireAt = max(anchor.addingTimeInterval(interval), Date().addingTimeInterval(60))

        let content = UNMutableNotificationContent()
        content.title = "Your Family File is \(percent)% done."
        content.body = "The next thing to add takes one minute."
        content.sound = .default
        content.categoryIdentifier = Category.nudge.rawValue
        content.userInfo = ["deepLink": next.deepLink.absoluteString]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        center.removePendingNotificationRequests(withIdentifiers: [nudgeID])
        center.add(UNNotificationRequest(identifier: nudgeID, content: content, trigger: trigger))
        defaults.set(fireAt, forKey: lastNudgeKey)
    }

    // MARK: Expirations (premium)

    static let leadDays = [60, 30, 7]

    func scheduleExpiration(id: UUID, title: String, expiresOn: Date) {
        cancelExpiration(id: id)
        for lead in Self.leadDays {
            guard let fire = Calendar.current.date(byAdding: .day, value: -lead, to: expiresOn), fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            content.title = "\(title) expires in \(lead) days"
            content.body = lead == 7 ? "This is the last reminder." : "Enough time to sort it out."
            content.sound = .default
            content.categoryIdentifier = Category.expiration.rawValue
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: fire)
            comps.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: "exp.\(id.uuidString).\(lead)", content: content, trigger: trigger))
        }
    }

    func cancelExpiration(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: Self.leadDays.map { "exp.\(id.uuidString).\($0)" })
    }

    // MARK: Tasks (premium)

    func scheduleTaskDue(id: UUID, title: String, due: Date) {
        cancelTaskDue(id: id)
        guard due > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Due today."
        content.sound = .default
        content.categoryIdentifier = Category.task.rawValue
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: due)
        comps.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: "task.\(id.uuidString)", content: content, trigger: trigger))
    }

    func cancelTaskDue(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["task.\(id.uuidString)"])
    }

    func cancelAllPremium() {
        Task {
            let pending = await center.pendingNotificationRequests()
            let ids = pending.map(\.identifier).filter { $0.hasPrefix("exp.") || $0.hasPrefix("task.") }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
