import Foundation
import RevenueCat
import Observation

/// Where premium features check whether they are unlocked. Never hide a
/// premium feature; show it locked and open the paywall on tap.
enum PremiumGate: String {
    case vault, vaultSave, expirationReminder, tasks, lifeSync, mealPlan, trustedSharing, cleanExport, sizeHistory, multipleHouseholds, onboarding

    var headline: String {
        switch self {
        case .vault: return "Keep every document safe"
        case .vaultSave: return "Keep this document safe"
        case .expirationReminder: return "Never miss an expiration"
        case .tasks: return "Let the app remember the house"
        case .lifeSync: return "See the week you actually have"
        case .mealPlan: return "Decide dinner once, together"
        case .trustedSharing: return "Share it with someone you trust"
        case .cleanExport: return "Export a sealed copy"
        case .sizeHistory: return "Keep track of how fast they grow"
        case .multipleHouseholds: return "Keep more than one file"
        case .onboarding: return "Now let the app remember for you."
        }
    }
}

/// RevenueCat identifiers. The products themselves are the two App Store
/// subscriptions in one group; RevenueCat wraps them in an offering with an
/// annual and a monthly package, and grants the "premium" entitlement.
enum ProductID {
    static let weekly = "co.petitehome.premium.weekly"
    static let monthly = "co.petitehome.premium.monthly"
    static let annual = "co.petitehome.premium.annual"
    static let all = [weekly, monthly, annual]
    static let entitlement = "premium"
}

/// The three plans on the paywall.
enum Plan: String, CaseIterable, Identifiable {
    case annual, monthly, weekly
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var per: String {
        switch self {
        case .annual: return "year"
        case .monthly: return "month"
        case .weekly: return "week"
        }
    }
    /// List prices shown before the store answers.
    var fallbackPrice: String {
        switch self {
        case .annual: return "$39.00"
        case .monthly: return "$4.99"
        case .weekly: return "$2.99"
        }
    }
}

/// Subscriptions through RevenueCat. The public surface stays small so the
/// views never touch the SDK: `isPremium`, the two packages, purchase,
/// restore. The Founding 500 unlock is local and layered on top.
@MainActor
@Observable
final class EntitlementStore {
    static let shared = EntitlementStore()

    /// Set in Info.plist as `RevenueCatAPIKey` (the public SDK key). Empty disables the store.
    static var apiKey: String { Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? "" }

    private(set) var annual: Package?
    private(set) var monthly: Package?
    private(set) var weekly: Package?
    private(set) var hasActiveSubscription = false
    private(set) var isInTrial = false
    private(set) var foundingUnlockExpiresAt: Date?
    /// TestFlight unlock: premium granted on this phone without a store, while RevenueCat has no key.
    private(set) var localTrialExpiresAt: Date?
    static let localTrialDays = 30
    private(set) var purchaseInProgress = false
    private(set) var storeAvailable = false
    var lastError: String?

    var isPremium: Bool {
        if hasActiveSubscription { return true }
        if let exp = foundingUnlockExpiresAt, exp > Date() { return true }
        if let exp = localTrialExpiresAt, exp > Date() { return true }
        return false
    }

    /// True while the app runs without a RevenueCat key: trials are granted locally.
    var usesLocalTrial: Bool { !Purchases.isConfigured }

    /// "$39.00" and "$4.99", from the store when it has answered, else the list prices.
    var annualPriceText: String { annual?.storeProduct.localizedPriceString ?? "$39.00" }
    var monthlyPriceText: String { monthly?.storeProduct.localizedPriceString ?? "$4.99" }
    var weeklyPriceText: String { weekly?.storeProduct.localizedPriceString ?? "$2.99" }

    func package(for plan: Plan) -> Package? {
        switch plan {
        case .annual: return annual
        case .monthly: return monthly
        case .weekly: return weekly
        }
    }

    func priceText(for plan: Plan) -> String {
        package(for: plan)?.storeProduct.localizedPriceString ?? plan.fallbackPrice
    }

    /// The introductory offer a plan carries, in words: "7 days free" or "$0.99 for the first week".
    /// Comes from the store, so the shape can change in App Store Connect without a code change.
    /// Before the store answers, the list configuration is assumed: $0.99 for the first week on every plan.
    func introText(for plan: Plan) -> String? {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount else {
            if package(for: plan) != nil { return nil }
            return "$0.99 for the first week"
        }
        let period = Self.describe(discount.subscriptionPeriod, count: discount.numberOfPeriods)
        switch discount.paymentMode {
        case .freeTrial: return "\(period) free"
        case .payUpFront: return "\(discount.localizedPriceString) for the first \(period)"
        case .payAsYouGo: return "\(discount.localizedPriceString) a \(Self.describe(discount.subscriptionPeriod, count: 1)) for \(period)"
        @unknown default: return nil
        }
    }

    /// True when starting this plan costs nothing today.
    func startsFree(_ plan: Plan) -> Bool {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount else { return false }
        return discount.paymentMode == .freeTrial
    }

    /// What the button should say for a plan.
    func callToAction(for plan: Plan) -> String {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount else {
            if package(for: plan) == nil { return "Start for $0.99" }
            return "Subscribe"
        }
        switch discount.paymentMode {
        case .freeTrial: return "Start free trial"
        default: return "Start for \(discount.localizedPriceString)"
        }
    }

    private static func describe(_ period: SubscriptionPeriod, count: Int) -> String {
        let n = period.value * max(count, 1)
        let unit: String
        switch period.unit {
        case .day: unit = "day"
        case .week: unit = "week"
        case .month: unit = "month"
        case .year: unit = "year"
        @unknown default: unit = "period"
        }
        if n == 7, period.unit == .day { return "7 days" }
        return n == 1 ? unit : "\(n) \(unit)s"
    }

    /// "Save 35%", from real prices when RevenueCat has them.
    var savingsText: String? {
        guard let a = annual?.storeProduct.price, let m = monthly?.storeProduct.price, m > 0 else { return "Save 35%" }
        let yearOfMonthly = m * 12
        guard yearOfMonthly > a else { return nil }
        let fraction = NSDecimalNumber(decimal: (yearOfMonthly - a) / yearOfMonthly).doubleValue
        return "Save \(Int((fraction * 100).rounded()))%"
    }

    private init() {
        loadFoundingUnlock()
        if let raw = KeychainService.shared.string(for: .localTrial), let interval = TimeInterval(raw) {
            localTrialExpiresAt = Date(timeIntervalSince1970: interval)
        }
    }

    /// Grants premium on this phone for `localTrialDays`. Only used when there is no store.
    @discardableResult
    func startLocalTrial() -> Bool {
        guard usesLocalTrial else { return false }
        if let exp = localTrialExpiresAt, exp > Date() { return true }
        let expires = Calendar.current.date(byAdding: .day, value: Self.localTrialDays, to: Date()) ?? Date()
        KeychainService.shared.setString(String(expires.timeIntervalSince1970), for: .localTrial)
        localTrialExpiresAt = expires
        Analytics.track(.trialStarted, ["product": "local_trial"])
        return true
    }

    /// Call once at launch, before anything reads `isPremium`.
    ///
    /// A RevenueCat Test Store key (`test_…`) is only allowed in debug builds; the
    /// SDK deliberately crashes a Release build that uses one. TestFlight builds are
    /// Release, so with a test key they run without a store and the paywall grants
    /// the local testing unlock instead. A production `appl_…` key works everywhere.
    static func configure() {
        guard !apiKey.isEmpty else { return }
        #if !DEBUG
        if apiKey.hasPrefix("test_") { return }
        #endif
        Purchases.logLevel = .warn
        Purchases.configure(with: Configuration.Builder(withAPIKey: apiKey).build())
        Task { @MainActor in
            shared.storeAvailable = true
            await shared.loadProducts()
            await shared.listenForCustomerInfo()
        }
    }

    func loadProducts() async {
        guard Purchases.isConfigured else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            annual = offerings.current?.annual
            monthly = offerings.current?.monthly
            weekly = offerings.current?.weekly
            if annual == nil, monthly == nil, weekly == nil { lastError = "Prices aren't loading. Check your connection." }
        } catch {
            lastError = "Couldn't load prices. Check your connection."
        }
        await refreshEntitlements()
    }

    /// Buys the package. Returns true when premium is active afterwards.
    func purchase(_ package: Package) async -> Bool {
        guard Purchases.isConfigured else { return startLocalTrial() }
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return false }
            apply(result.customerInfo)
            if hasActiveSubscription {
                Analytics.track(isInTrial ? .trialStarted : .subscriptionConverted, ["product": package.storeProduct.productIdentifier])
            }
            return hasActiveSubscription
        } catch {
            lastError = "That didn't go through. Nothing was charged."
            return false
        }
    }

    func restore() async {
        guard Purchases.isConfigured else { return }
        if let info = try? await Purchases.shared.restorePurchases() { apply(info) }
    }

    func refreshEntitlements() async {
        guard Purchases.isConfigured else { return }
        if let info = try? await Purchases.shared.customerInfo() { apply(info) }
    }

    /// Pass the Sign in with Apple user ID so purchases follow the person across devices.
    func identify(userID: String) async {
        guard Purchases.isConfigured else { return }
        if let result = try? await Purchases.shared.logIn(userID) { apply(result.customerInfo) }
    }

    private func listenForCustomerInfo() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        let wasActive = hasActiveSubscription
        let entitlement = info.entitlements[ProductID.entitlement]
        hasActiveSubscription = entitlement?.isActive ?? false
        isInTrial = entitlement?.periodType == .trial
        if hasActiveSubscription && !wasActive && !isInTrial {
            Analytics.track(.subscriptionConverted)
        }
        if !hasActiveSubscription {
            NotificationService.shared.cancelAllPremium()
        }
    }

    // MARK: Founding 500

    private func loadFoundingUnlock() {
        if let raw = KeychainService.shared.string(for: .foundingUnlock, synchronizable: true),
           let interval = TimeInterval(raw) {
            foundingUnlockExpiresAt = Date(timeIntervalSince1970: interval)
        }
    }

    /// Redeems a Founding 500 reservation code: 12 months of premium.
    @discardableResult
    func redeemFoundingCode(_ code: String) -> Bool {
        guard FoundingCode.isValid(code) else { return false }
        let expires = Calendar.current.date(byAdding: .month, value: 12, to: Date()) ?? Date()
        KeychainService.shared.setString(String(expires.timeIntervalSince1970), for: .foundingUnlock, synchronizable: true)
        foundingUnlockExpiresAt = expires
        Analytics.track(.foundingCodeRedeemed)
        return true
    }
}

/// Founding 500 reservation codes. Format: PH-XXXX-XXXX where the last group
/// is a check over the first, so typos fail locally without a server call.
/// The code list itself is issued by the website's reservation flow.
enum FoundingCode {
    private static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    static func normalize(_ raw: String) -> String {
        raw.uppercased().filter { !$0.isWhitespace }
    }

    static func isValid(_ raw: String) -> Bool {
        let code = normalize(raw)
        let parts = code.split(separator: "-").map(String.init)
        guard parts.count == 3, parts[0] == "PH", parts[1].count == 4, parts[2].count == 4 else { return false }
        return checksum(parts[1]) == parts[2]
    }

    static func checksum(_ body: String) -> String {
        var acc: UInt32 = 5381
        for scalar in body.unicodeScalars {
            acc = (acc &* 33) ^ scalar.value
        }
        var out = ""
        var value = acc
        for _ in 0..<4 {
            out.append(alphabet[Int(value % UInt32(alphabet.count))])
            value /= UInt32(alphabet.count)
        }
        return out
    }

    /// Makes a code from a body, for issuing (used by tests and the ops script).
    static func make(body: String) -> String { "PH-\(body.uppercased())-\(checksum(body.uppercased()))" }
}
