import SwiftUI

/// A labelled text input: white field on cream, radius 10.
struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalization: TextInputAutocapitalization = .words

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Typography.label)
                .foregroundStyle(Theme.Colors.sandDeep)
            TextField(placeholder, text: $text)
                .font(Typography.body)
                .foregroundStyle(Theme.Colors.ink)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(autocapitalization)
                .padding(.horizontal, 14)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                        .fill(Theme.Colors.white)
                )
        }
    }
}

/// Multi-line notes field.
struct LabeledTextEditor: View {
    let label: String
    @Binding var text: String
    var hint: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(Typography.label)
                .foregroundStyle(Theme.Colors.sandDeep)
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(hint)
                        .font(Typography.body)
                        .foregroundStyle(Theme.Colors.sandDeep.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                }
                TextEditor(text: $text)
                    .font(Typography.body)
                    .foregroundStyle(Theme.Colors.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minHeight: 110)
            }
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .fill(Theme.Colors.white)
            )
        }
    }
}

/// A row in a Family File section: label, value (or the instruction), chevron.
struct FieldRow: View {
    let label: String
    let value: String?
    let instruction: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Colors.sandDeep)
                HStack {
                    Text(value?.isEmpty == false ? value! : instruction)
                        .font(Typography.body)
                        .foregroundStyle(value?.isEmpty == false ? Theme.Colors.ink : Theme.Colors.accentText)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.sandDeep)
                }
            }
            .padding(.vertical, Theme.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Section header on a screen: serif title with optional count.
struct SectionHeader: View {
    let title: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.ink)
            Spacer()
            if let detail {
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(Theme.Colors.sandDeep)
            }
        }
    }
}

/// The paywall-gated feature preview: content greyed with the pill on top.
struct LockedPreview<Content: View>: View {
    var gate: PremiumGate
    var onTap: () -> Void
    /// Banner above the preview (default) or below it, for previews that sit inside a card.
    var bannerFirst: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            if bannerFirst { PremiumGateBanner(gate: gate, onTap: onTap) }
            Button(action: onTap) {
                content()
                    .opacity(0.5)
                    .allowsHitTesting(false)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Preview of \(gate.headline). Premium feature.")
            if !bannerFirst { PremiumGateBanner(gate: gate, onTap: onTap).padding(Theme.Spacing.md) }
        }
    }
}

/// The premium gate as its own card: the lock, the headline, one sentence of
/// value, a button. It never overlaps content; the preview sits next to it, dimmed.
struct PremiumGateBanner: View {
    @Environment(EntitlementStore.self) private var entitlements
    let gate: PremiumGate
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: "lock.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.Colors.accentText)
                Text("Premium keeps this for you").capsLabel()
            }
            Text(gate.headline).font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
            Text(gate.valueLine).font(Typography.body).foregroundStyle(Theme.Colors.sandDeep).fixedSize(horizontal: false, vertical: true)
            Button(entitlements.usesLocalTrial ? "Unlock while we're testing" : "See plans", action: onTap)
                .buttonStyle(.primary)
                .padding(.top, Theme.Spacing.xs)
            Text(entitlements.usesLocalTrial
                 ? "Free for \(EntitlementStore.localTrialDays) days while we're in testing."
                 : "$0.99 for your first week, then weekly, monthly or yearly. Cancel anytime.")
                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.Colors.powderBlueMist))
    }
}
