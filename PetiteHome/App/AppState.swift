import Foundation
import SwiftUI
import Observation

enum AppTab: Hashable {
    case home, familyFile, tasks, vault, picks
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

    var selectedTab: AppTab = .home
    var paywallGate: PremiumGate?
    var showSettings = false
    var pendingField: FamilyFileField?
    var pendingSharedFile: (title: String, pdf: Data)?

    init() {
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboardingComplete)
        currentHouseholdID = defaults.string(forKey: Keys.currentHousehold).flatMap(UUID.init(uuidString:))
        premiumOfferSeenInOnboarding = defaults.bool(forKey: Keys.premiumOfferSeen)
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
}
