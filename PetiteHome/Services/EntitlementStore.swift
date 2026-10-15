import Foundation
import RevenueCat
import Observation

/// Where premium features check whether they are unlocked. Never hide a
/// premium feature; show it locked and open the paywall on tap.
enum PremiumGate: String {
    case vault, vaultSave, expirationReminder, tasks, lifeSync, mealPlan, trustedSharing, cleanExport, sizeHistory, multipleHouseholds, onboarding

    /// One sentence on what premium does here. Shown under the headline on every locked area.
    var valueLine: String {
        switch self {
        case .vault: return "Photos of the papers you can't lose, encrypted on your phone before they sync. Only you can open them."
        case .vaultSave: return "Keep the scan, encrypted, next to the rest of the documents."
        case .expirationReminder: return "A heads-up 60, 30 and 7 days before passports, car seats and insurance run out."
        case .tasks: return "The chores on a rhythm, in your Reminders app too, for either of you to check off."
        case .lifeSync: return "Both of your calendars, the chores, dinner and plans on one week you can both see."
        case .mealPlan: return "Plan the week with your partner, save the recipes you make, and get the list written for you."
        case .trustedSharing: return "A read-only copy for a grandparent or the guardian, from a link that expires when you say."
        case .cleanExport: return "The printable file without the numbers that shouldn't travel."
        case .sizeHistory: return "Every size you've logged, so you know what fits before you order."
        case .multipleHouseholds: return "A second file for a second home, or for the kids' other house."
        case .onboarding: return "Reminders, the vault and the Planner, kept for you."
        }
    }

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
        case .onboarding: return "Now let us do the remembering."
        }
    }
}

/// RevenueCat identifiers. The products are three App Store subscriptions in
/// one group; RevenueCat wraps them in an offering with weekly, monthly and
/// annual packages ($rc_weekly, $rc_monthly, $rc_annual), and grants the
/// "Premium" entitlement (the identifier is case-sensitive).
enum ProductID {
    static let weekly = "co.petitehome.premium.weekly"
    static let monthly = "co.petitehome.premium.monthly"
    static let annual = "co.petitehome.premium.annual"
    static let all = [weekly, monthly, annual]
    static let entitlement = "Premium"
}

/// The three plans on the paywall, in row order. The app is subscription-only: no free tier.
/// Only the weekly plan carries an introductory offer ($0.99 for the first week).
enum Plan: String, CaseIterable, Identifiable {
    case weekly, monthly, annual
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var per: String {
        switch self {
        case .weekly: return "week"
        case .monthly: return "month"
        case .annual: return "year"
        }
    }
    /// List prices shown before the store answers.
    var fallbackPrice: String {
        switch self {
        case .weekly: return "$5.99"
        case .monthly: return "$14.99"
        case .annual: return "$124.99"
        }
    }
    /// The same list prices as numbers, for per-week math before the store answers.
    var fallbackAmount: Decimal {
        switch self {
        case .weekly: return 5.99
        case .monthly: return 14.99
        case .annual: return 124.99
        }
    }
    /// Weeks a plan's price buys, for comparing plans per week.
    var weeksPerPeriod: Decimal {
        switch self {
        case .weekly: return 1
        case .monthly: return Decimal(52) / 12
        case .annual: return 52
        }
    }
    /// Whether the list configuration gives this plan an intro offer. Used only before the store answers.
    var hasIntroOfferByDefault: Bool { self == .weekly }
}

/// Subscriptions through RevenueCat. The public surface stays small so the
/// views never touch the SDK: `isPremium`, the three packages, purchase,
/// restore. The Founding 500 unlock is local and layered on top.
@MainActor
@Observable
final class EntitlementStore {
    static let shared = EntitlementStore()

    /// Set in Info.plist as `RevenueCatAPIKey` (the public SDK key). Empty disables the store.
    static var apiKey: String { Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String ?? "" }

    private(set) var weekly: Package?
    private(set) var monthly: Package?
    private(set) var annual: Package?
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

    /// The plans to show: every plan before the store answers, then only the ones it returned,
    /// so a package missing from the offering never shows a row that cannot be bought.
    var availablePlans: [Plan] {
        let loaded = Plan.allCases.filter { package(for: $0) != nil }
        return loaded.isEmpty ? Plan.allCases : loaded
    }

    /// True until the store answers without a weekly package. The headline, the onboarding
    /// line and the per-week comparisons all rest on the weekly plan, so they step aside without it.
    var weeklyOffered: Bool { availablePlans.contains(.weekly) }

    func package(for plan: Plan) -> Package? {
        switch plan {
        case .weekly: return weekly
        case .monthly: return monthly
        case .annual: return annual
        }
    }

    /// "$5.99", from the store when it has answered, else the list price.
    func priceText(for plan: Plan) -> String {
        package(for: plan)?.storeProduct.localizedPriceString ?? plan.fallbackPrice
    }

    private func amount(for plan: Plan) -> Decimal {
        package(for: plan)?.storeProduct.price ?? plan.fallbackAmount
    }

    /// Formats an amount in the plan's store currency, or as dollars before the store answers.
    private func formatted(_ amount: Decimal, like plan: Plan) -> String {
        if let formatter = package(for: plan)?.storeProduct.priceFormatter,
           let text = formatter.string(from: amount as NSDecimalNumber) {
            return text
        }
        return "$" + String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
    }

    /// "$3.46/wk": what a month or a year costs per week. Nil for the weekly plan itself.
    func perWeekText(for plan: Plan) -> String? {
        guard plan != .weekly, weeklyOffered else { return nil }
        return "\(formatted(amount(for: plan) / plan.weeksPerPeriod, like: plan))/wk"
    }

    /// "Save 42%" against paying week by week. Nil for the weekly plan, or when it saves nothing.
    func savingsText(for plan: Plan) -> String? {
        guard plan != .weekly, weeklyOffered else { return nil }
        let weekly = amount(for: .weekly)
        let perWeek = amount(for: plan) / plan.weeksPerPeriod
        guard weekly > 0, perWeek < weekly else { return nil }
        let fraction = NSDecimalNumber(decimal: (weekly - perWeek) / weekly).doubleValue
        return "Save \(Int((fraction * 100).rounded()))%"
    }

    /// "$3.46/wk, save 42%" for the monthly and annual rows.
    func comparisonText(for plan: Plan) -> String? {
        guard let perWeek = perWeekText(for: plan) else { return nil }
        guard let savings = savingsText(for: plan) else { return perWeek }
        return "\(perWeek), \(savings.lowercased())"
    }

    /// The introductory offer a plan carries, in words: "7 days free" or "$0.99 for the first week".
    /// Comes from the store, so the shape can change in App Store Connect without a code change.
    /// Before the store answers, the list configuration is assumed: $0.99 for the first week on weekly only.
    func introText(for plan: Plan) -> String? {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount else {
            if package(for: plan) != nil { return nil }
            return plan.hasIntroOfferByDefault ? "$0.99 for the first week" : nil
        }
        let total = Self.describe(discount.subscriptionPeriod, count: discount.numberOfPeriods)
        switch discount.paymentMode {
        case .freeTrial: return "\(total) free"
        case .payUpFront: return "\(discount.localizedPriceString) for the first \(total)"
        case .payAsYouGo:
            // One period billed once reads the same as pay-up-front; several read per period.
            if discount.numberOfPeriods <= 1 { return "\(discount.localizedPriceString) for the first \(total)" }
            return "\(discount.localizedPriceString) a \(Self.describe(discount.subscriptionPeriod, count: 1)) for \(total)"
        @unknown default: return nil
        }
    }

    /// The intro offer as the opening clause of the fine print: "First week $0.99" or "First 7 days free".
    func introFinePrint(for plan: Plan) -> String? {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount else {
            if package(for: plan) != nil { return nil }
            return plan.hasIntroOfferByDefault ? "First week $0.99" : nil
        }
        let total = Self.describe(discount.subscriptionPeriod, count: discount.numberOfPeriods)
        switch discount.paymentMode {
        case .freeTrial: return "First \(total) free"
        case .payUpFront: return "First \(total) \(discount.localizedPriceString)"
        case .payAsYouGo:
            if discount.numberOfPeriods <= 1 { return "First \(total) \(discount.localizedPriceString)" }
            return "First \(total) \(discount.localizedPriceString) a \(Self.describe(discount.subscriptionPeriod, count: 1))"
        @unknown default: return nil
        }
    }

    /// "$0.99": the intro offer's price alone, for the headline. Nil when the plan has none.
    func introPriceText(for plan: Plan) -> String? {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount else {
            if package(for: plan) != nil { return nil }
            return plan.hasIntroOfferByDefault ? "$0.99" : nil
        }
        return discount.paymentMode == .freeTrial ? nil : discount.localizedPriceString
    }

    /// True when starting this plan costs nothing today.
    func startsFree(_ plan: Plan) -> Bool {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount else { return false }
        return discount.paymentMode == .freeTrial
    }

    /// What the button should say for a plan: "Start for $0.99" when the store returns an intro
    /// offer (pay-up-front or pay-as-you-go), "Start free trial" for a trial, else
    /// "Subscribe for $14.99/month".
    func callToAction(for plan: Plan) -> String {
        guard let discount = package(for: plan)?.storeProduct.introductoryDiscount else {
            if package(for: plan) == nil, plan.hasIntroOfferByDefault { return "Start for $0.99" }
            return "Subscribe for \(priceText(for: plan))/\(plan.per)"
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
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif
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
            weekly = offerings.current?.weekly
            monthly = offerings.current?.monthly
            annual = offerings.current?.annual
            if weekly == nil, monthly == nil, annual == nil { lastError = "Prices aren't loading. Check your connection." }
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
