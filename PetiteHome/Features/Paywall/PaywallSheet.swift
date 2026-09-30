import SwiftUI

/// The paywall, reused at every gate. Headline changes by gate; the three
/// bullets sit in an ink card; plans are rows with a radio mark and a savings
/// badge; the trial CTA is pinned to the bottom with the fine print; restore
/// and close are always present.
struct PaywallSheet: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    let gate: PremiumGate
    @State private var annualSelected = true
    @State private var lastLocalError: String?

    static func priceLine(_ store: EntitlementStore) -> String {
        "\(store.annualPriceText)/year · 7-day free trial · cancel anytime"
    }

    private var annualPrice: String { entitlements.annualPriceText }
    private var monthlyPrice: String { entitlements.monthlyPriceText }
    private var savings: String? { entitlements.savingsText }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep).frame(width: 40, height: 40)
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, Theme.Spacing.md)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Eyebrow(text: "Petite Home premium").reveal(0)
                    Text(gate.headline).font(Typography.hook).lineSpacing(6).foregroundStyle(Theme.Colors.ink).fixedSize(horizontal: false, vertical: true).reveal(1)
                    featuresCard.reveal(2)
                    VStack(spacing: Theme.Spacing.sm) {
                        Text("7 days free, then").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        planRow(title: "Annual", price: "\(annualPrice) / year", badge: savings, selected: annualSelected) { annualSelected = true }
                        planRow(title: "Monthly", price: "\(monthlyPrice) / month", badge: nil, selected: !annualSelected) { annualSelected = false }
                    }
                    .reveal(3)
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .scrollIndicators(.hidden)
            // Pinned CTA
            VStack(spacing: Theme.Spacing.sm) {
                if let error = entitlements.lastError {
                    Text(error).font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                }
                if entitlements.purchaseInProgress { PulsingDots() }
                Button(entitlements.purchaseInProgress ? "One moment" : "Start free trial") {
                    if entitlements.usesLocalTrial {
                        if entitlements.startLocalTrial() { dismiss() }
                        return
                    }
                    Task {
                        let package = annualSelected ? entitlements.annual : entitlements.monthly
                        guard let package else { lastLocalError = "Prices haven't loaded yet. Try again in a moment."; return }
                        if await entitlements.purchase(package) { dismiss() }
                    }
                }
                .buttonStyle(.primary(enabled: !entitlements.purchaseInProgress)).disabled(entitlements.purchaseInProgress)
                if let lastLocalError { Text(lastLocalError).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
                Text(entitlements.usesLocalTrial
                     ? "Free for \(EntitlementStore.localTrialDays) days while we're in testing. Nothing to cancel."
                     : "Nothing is charged for 7 days. Then it renews automatically at the price shown until you cancel in Settings.")
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep).multilineTextAlignment(.center)
                HStack(spacing: Theme.Spacing.lg) {
                    Button("Restore purchases") { Task { await entitlements.restore(); if entitlements.isPremium { dismiss() } } }
                    Link("Privacy", destination: URL(string: "https://petitehome.co/privacy")!)
                    Link("Terms", destination: URL(string: "https://petitehome.co/terms")!)
                }
                .font(Typography.caption).foregroundStyle(Theme.Colors.powderBlueDk)
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.top, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.lg)
            .background(Theme.Colors.cream)
            .overlay(alignment: .top) { SandDivider() }
        }
        .screenBackground()
        .presentationBackground(Theme.Colors.cream)
        .presentationDragIndicator(.visible)
        .task { if entitlements.annual == nil { await entitlements.loadProducts() } }
    }

    /// The three bullets, cream on ink, with the wordmark ghosted in the corner.
    private var featuresCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                bullet("bell", "Reminds you when passports, car seats, and insurance expire")
                bullet("lock.doc", "Keeps birth certificates and SSN cards in an encrypted vault")
                bullet("calendar", "The \(AppCopy.planner): both calendars, tasks, meals and date nights on one week, shared with your partner")
            }
            .padding(Theme.Spacing.xl)
            Text("PH")
                .font(Typography.serif(44))
                .foregroundStyle(Theme.Colors.powderBlue.opacity(0.12))
                .padding(Theme.Spacing.md)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.Colors.ink))
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon).font(.system(size: 18, weight: .regular)).foregroundStyle(Theme.Colors.powderBlue).frame(width: 24)
            Text(text).font(Typography.body).lineSpacing(3).foregroundStyle(Theme.Colors.cream).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func planRow(title: String, price: String, badge: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title).font(Typography.serif(18)).foregroundStyle(Theme.Colors.ink)
                        if let badge {
                            Text(badge).font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(Theme.Colors.success.opacity(0.25)))
                                .foregroundStyle(Theme.Colors.ink)
                        }
                    }
                    Text(price).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.Colors.powderBlueDk : Theme.Colors.sand)
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(Theme.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(selected ? Theme.Colors.powderBlueMist : Theme.Colors.creamDeep))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).stroke(selected ? Theme.Colors.powderBlue : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .animation(Motion.select, value: selected)
    }
}
