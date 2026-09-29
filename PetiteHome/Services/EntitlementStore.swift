import Foundation
import StoreKit
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

enum ProductID {
    static let monthly = "co.petitehome.premium.monthly"
    static let annual = "co.petitehome.premium.annual"
    static let all = [monthly, annual]
}

@MainActor
@Observable
final class EntitlementStore {
    static let shared = EntitlementStore()

    private(set) var products: [Product] = []
    private(set) var hasActiveSubscription = false
    private(set) var isInTrial = false
    private(set) var foundingUnlockExpiresAt: Date?
    private(set) var purchaseInProgress = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    var isPremium: Bool {
        if hasActiveSubscription { return true }
        if let exp = foundingUnlockExpiresAt, exp > Date() { return true }
        return false
    }

    var monthly: Product? { products.first { $0.id == ProductID.monthly } }
    var annual: Product? { products.first { $0.id == ProductID.annual } }

    private init() {
        loadFoundingUnlock()
        updatesTask = Task { await listenForTransactions() }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: ProductID.all).sorted { $0.price > $1.price }
        } catch {
            lastError = "Couldn't load prices. Check your connection."
        }
        await refreshEntitlements()
    }

    func purchase(_ product: Product) async -> Bool {
        purchaseInProgress = true
        defer { purchaseInProgress = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                Analytics.track(.trialStarted, ["product": product.id])
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "That didn't go through. Nothing was charged."
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var active = false
        var trial = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil, (transaction.expirationDate ?? .distantFuture) > Date() {
                active = true
                if transaction.offerType == .introductory { trial = true }
            }
        }
        let wasActive = hasActiveSubscription
        hasActiveSubscription = active
        isInTrial = trial
        if active && !wasActive && !trial {
            Analytics.track(.subscriptionConverted)
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreKitError.notEntitled
        case .verified(let safe): return safe
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
