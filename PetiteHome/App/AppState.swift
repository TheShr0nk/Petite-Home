import Foundation
import SwiftUI
import Observation

enum AppTab: Hashable {
    case home, familyFile, lifeSync, vault, picks
    /// Kept so older deep links and the paywall gate for tasks still land somewhere sensible.
    static let tasks = AppTab.lifeSync
}

/// Where the app is: onboarding or the tabs, which household is current,
/// which paywall gate is open, and any pending deep link.
@MainActor
@Observable
final class AppState {
    private let defaults = UserDefaults.standard
    private enum Keys {
        static let onboardingComplete = "app.onboardingComplete"
        static let currentHousehold = "app.currentHouseholdID"
        static let premiumOfferSeen = "app.premiumOfferSeenInOnboarding"
        static let onboardingCompletedAt = "app.onboardingCompletedAt"
        static let currentAdult = "app.currentAdultID"
    }

    var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.onboardingComplete)
            if hasCompletedOnboarding, defaults.object(forKey: Keys.onboardingCompletedAt) == nil {
                defaults.set(Date(), forKey: Keys.onboardingCompletedAt)
            }
        }
    }
    var currentHouseholdID: UUID? {
        didSet { defaults.set(currentHouseholdID?.uuidString, forKey: Keys.currentHousehold) }
    }
    var premiumOfferSeenInOnboarding: Bool {
        didSet { defaults.set(premiumOfferSeenInOnboarding, forKey: Keys.premiumOfferSeen) }
    }
    /// Which adult this phone belongs to. Life Sync mirrors that adult's calendars.
    var currentAdultID: UUID? {
        didSet { defaults.set(currentAdultID?.uuidString, forKey: Keys.currentAdult) }
    }
    var lifeSyncSegment: LifeSyncSegment = .week

    var selectedTab: AppTab = .home
    var paywallGate: PremiumGate?
    var showSettings = false
    var pendingField: FamilyFileField?
    var pendingSharedFile: (title: String, pdf: Data)?

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingComplete)
        currentHouseholdID = defaults.string(forKey: Keys.currentHousehold).flatMap(UUID.init(uuidString:))
        premiumOfferSeenInOnboarding = defaults.bool(forKey: Keys.premiumOfferSeen)
        currentAdultID = defaults.string(forKey: Keys.currentAdult).flatMap(UUID.init(uuidString:))
    }

    /// The adult using this phone: the explicit choice, else whoever signed in with Apple here, else the owner.
    func currentAdult(in household: Household) -> Adult? {
        if let id = currentAdultID, let a = household.adults.first(where: { $0.id == id }) { return a }
        if let apple = AppleSignIn.storedUserID, household.ownerAppleUserID == apple { return household.owner }
        return household.owner ?? household.adults.first
    }

    func showPaywall(_ gate: PremiumGate) {
        Analytics.track(.paywallViewed, ["gate": gate.rawValue])
        paywallGate = gate
    }

    /// petitehome://familyfile/<field>
    func handle(url: URL) {
        guard url.scheme == FamilyFileField.deepLinkScheme else { return }
        if url.host == "familyfile", let field = FamilyFileField(rawValue: url.lastPathComponent) {
            open(field)
        }
    }

    func open(_ field: FamilyFileField) {
        selectedTab = .familyFile
        pendingField = field
    }

    func openTasks() {
        selectedTab = .lifeSync
        lifeSyncSegment = .tasks
    }

    func openMeals() {
        selectedTab = .lifeSync
        lifeSyncSegment = .meals
    }
}

enum LifeSyncSegment: String, CaseIterable, Identifiable {
    case week, meals, tasks
    var id: String { rawValue }
    var label: String {
        switch self {
        case .week: return "Week"
        case .meals: return "Meals"
        case .tasks: return "Tasks"
        }
    }
}
