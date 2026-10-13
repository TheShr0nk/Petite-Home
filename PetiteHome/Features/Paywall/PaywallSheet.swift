import SwiftUI

/// The paywall, reused at every gate. Headline changes by gate; the three
/// bullets sit in an ink card; plans are rows with a radio mark and a savings
/// badge; the trial CTA is pinned to the bottom with the fine print; restore
/// and close are always present.
struct PaywallSheet: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    let gate: PremiumGate
    /// False when this is the wall after onboarding: no close button, a code field instead.
    var dismissible: Bool = true
    @State private var selected: Plan = .annual
    @State private var lastLocalError: String?
    @State private var foundingCode = ""
    @State private var foundingResult: String?

    static func priceLine(_ store: EntitlementStore) -> String {
        "$0.99 for the first week · then \(store.monthlyPriceText) a month or \(store.annualPriceText) a year · cancel anytime"
    }

    private var savings: String? { entitlements.savingsText }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if dismissible {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Close")
                } else {
                    Color.clear.frame(height: 44)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Eyebrow(text: "Petite Home premium").reveal(0)
                    Text(gate.headline).font(Typography.hook).lineSpacing(6).foregroundStyle(Theme.Colors.ink).fixedSize(horizontal: false, vertical: true).reveal(1)
                    featuresCard.reveal(2)
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(Plan.allCases) { plan in
                            planRow(plan: plan,
                                    badge: plan == .annual ? savings : nil,
                                    selected: selected == plan) { selected = plan }
                        }
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
                Button(entitlements.purchaseInProgress ? "One moment" : (entitlements.usesLocalTrial ? "Unlock while we're testing" : entitlements.callToAction(for: selected))) {
                    if entitlements.usesLocalTrial {
                        if entitlements.startLocalTrial() { dismiss() }
                        return
                    }
                    Task {
                        guard let package = entitlements.package(for: selected) else { lastLocalError = "Prices haven't loaded yet. Try again in a moment."; return }
                        if await entitlements.purchase(package) { dismiss() }
                    }
                }
                .buttonStyle(.primary(enabled: !entitlements.purchaseInProgress)).disabled(entitlements.purchaseInProgress)
                if let lastLocalError { Text(lastLocalError).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
                Text(entitlements.usesLocalTrial
                     ? "Free for \(EntitlementStore.localTrialDays) days while we're in testing. Nothing to cancel."
                     : finePrint)
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep).multilineTextAlignment(.center)
                if !entitlements.usesLocalTrial {
                    Text("One subscription covers your partner too, through Apple Family Sharing.")
                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep).multilineTextAlignment(.center)
                }
                if !dismissible {
                    HStack(spacing: Theme.Spacing.sm) {
                        TextField("Founding 500 code", text: $foundingCode)
                            .font(Typography.callout).textInputAutocapitalization(.characters).autocorrectionDisabled()
                            .padding(.horizontal, 12).frame(minHeight: 40)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(Theme.Colors.white))
                        Button("Redeem") {
                            foundingResult = entitlements.redeemFoundingCode(foundingCode) ? "Premium is on for 12 months. Thank you for being early." : "That code didn't match."
                        }
                        .font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.accentText).disabled(foundingCode.isEmpty)
                    }
                    if let foundingResult { Text(foundingResult).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) }
                }
                HStack(spacing: Theme.Spacing.lg) {
                    Button("Restore purchases") { Task { await entitlements.restore(); if entitlements.isPremium { dismiss() } } }
                    Link("Privacy", destination: URL(string: "https://petitehome.co/privacy")!)
                    Link("Terms", destination: URL(string: "https://petitehome.co/terms")!)
                }
                .font(Typography.caption).foregroundStyle(Theme.Colors.accentText)
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

    /// Apple wants the intro, the renewal price and the auto-renewal stated together.
    private var finePrint: String {
        let price = "\(entitlements.priceText(for: selected)) a \(selected.per)"
        if let intro = entitlements.introText(for: selected) {
            return "\(intro), then \(price). Renews automatically until you cancel in Settings."
        }
        return "\(price), renewing automatically until you cancel in Settings."
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
                .foregroundStyle(Theme.Colors.Fixed.powderBlue.opacity(0.12))
                .padding(Theme.Spacing.md)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.Colors.Fixed.ink))
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon).font(.system(size: 18, weight: .regular)).foregroundStyle(Theme.Colors.Fixed.powderBlue).frame(width: 24)
            Text(text).font(Typography.body).lineSpacing(3).foregroundStyle(Theme.Colors.Fixed.cream).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func planRow(plan: Plan, badge: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(plan.title).font(Typography.serif(18)).foregroundStyle(Theme.Colors.ink)
                        if let badge {
                            Text(badge).font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill((plan == .annual ? Theme.Colors.success : Theme.Colors.powderBlue).opacity(0.3)))
                                .foregroundStyle(Theme.Colors.ink)
                        }
                    }
                    Text("\(entitlements.priceText(for: plan)) / \(plan.per)").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    if let intro = entitlements.introText(for: plan) {
                        Text(intro).font(Typography.caption).foregroundStyle(Theme.Colors.accentText)
                    }
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.Colors.accentText : Theme.Colors.sand)
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
