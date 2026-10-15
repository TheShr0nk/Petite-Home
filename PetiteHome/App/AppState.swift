import Foundation
import SwiftUI
import Observation

enum AppTab: Hashable {
    case home, familyFile, lifeSync, vault
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
        static let partnerWelcome = "app.partnerWelcomePending"
        static let appearance = "app.appearance"
        static let awaitingShare = "app.awaitingSharedHousehold"
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
    /// Set when a household arrives through a partner's invite: the short partner welcome runs before the tabs.
    var partnerWelcomePending: Bool {
        didSet { defaults.set(partnerWelcomePending, forKey: Keys.partnerWelcome) }
    }
    /// True between accepting a partner's invite and the household arriving from iCloud.
    var awaitingSharedHousehold: Bool {
        didSet { defaults.set(awaitingSharedHousehold, forKey: Keys.awaitingShare) }
    }
    /// System, light or dark. Chosen in Settings; system by default.
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
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
        partnerWelcomePending = defaults.bool(forKey: Keys.partnerWelcome)
        appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        awaitingSharedHousehold = defaults.bool(forKey: Keys.awaitingShare)
    }

    /// The adult using this phone: the explicit choice, else the owner if this iCloud account created the household, else the partner.
    func currentAdult(in household: Household) -> Adult? {
        if let id = currentAdultID, let a = household.adults.first(where: { $0.uuid == id }) { return a }
        if let mine = CloudIdentity.cachedUserID, household.ownerUserID == mine { return household.owner }
        if CloudIdentity.cachedUserID != nil, household.ownerUserID != nil { return household.partner ?? household.owner }
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
        } else if url.host == "tasks" {
            openTasks()
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

    func openPlans() {
        selectedTab = .lifeSync
        lifeSyncSegment = .plans
    }
}

enum LifeSyncSegment: String, CaseIterable, Identifiable {
    case week, plans, meals, tasks
    var id: String { rawValue }
    var label: String {
        switch self {
        case .week: return "Week"
        case .plans: return "Plans"
        case .meals: return "Meals"
        case .tasks: return "Tasks"
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: return "Match the phone"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
