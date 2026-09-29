import SwiftUI
import StoreKit

/// The paywall, reused at every gate. Headline changes by gate; bullets,
/// price toggle (annual default), trial CTA, restore link, close top-right.
struct PaywallSheet: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    let gate: PremiumGate
    @State private var annualSelected = true

    static func priceLine(_ store: EntitlementStore) -> String {
        if let annual = store.annual {
            return "\(annual.displayPrice)/year · 7-day free trial · cancel anytime"
        }
        return "$39/year · 7-day free trial · cancel anytime"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep).frame(width: 40, height: 40)
                }
                .accessibilityLabel("Close")
            }
            Text(gate.headline).font(Typography.hook).lineSpacing(6).foregroundStyle(Theme.Colors.ink).fixedSize(horizontal: false, vertical: true)
            PremiumBullets()
            HStack(spacing: Theme.Spacing.sm) {
                priceOption(title: "Annual", price: entitlements.annual?.displayPrice ?? "$39.00", per: "year", detail: "Best value", selected: annualSelected) { annualSelected = true }
                priceOption(title: "Monthly", price: entitlements.monthly?.displayPrice ?? "$4.99", per: "month", detail: nil, selected: !annualSelected) { annualSelected = false }
            }
            Spacer()
            if let error = entitlements.lastError {
                Text(error).font(Typography.caption).foregroundStyle(Theme.Colors.danger)
            }
            Button(entitlements.purchaseInProgress ? "One moment" : "Start free trial") {
                Task {
                    let product = annualSelected ? entitlements.annual : entitlements.monthly
                    guard let product else { return }
                    if await entitlements.purchase(product) { dismiss() }
                }
            }
            .buttonStyle(.primary(enabled: !entitlements.purchaseInProgress)).disabled(entitlements.purchaseInProgress)
            Text("7-day free trial, then \(annualSelected ? (entitlements.annual?.displayPrice ?? "$39.00") + "/year" : (entitlements.monthly?.displayPrice ?? "$4.99") + "/month"). Cancel anytime.")
                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep).frame(maxWidth: .infinity)
            Button("Restore purchases") { Task { await entitlements.restore(); if entitlements.isPremium { dismiss() } } }
                .buttonStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.bottom, Theme.Spacing.lg)
        .screenBackground()
        .presentationBackground(Theme.Colors.cream)
        .task { if entitlements.products.isEmpty { await entitlements.loadProducts() } }
    }

    private func priceOption(title: String, price: String, per: String, detail: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(Typography.label).foregroundStyle(Theme.Colors.ink)
                Text("\(price)/\(per)").font(Typography.serif(20)).foregroundStyle(Theme.Colors.ink)
                if let detail { Text(detail).font(Typography.caption).foregroundStyle(Theme.Colors.powderBlueDk) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(selected ? Theme.Colors.powderBlue : Theme.Colors.creamDeep))
        }
        .buttonStyle(.plain)
    }
}
