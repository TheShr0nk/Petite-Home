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
                        .foregroundStyle(value?.isEmpty == false ? Theme.Colors.ink : Theme.Colors.powderBlueDk)
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
    var onTap: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                content()
                    .opacity(0.45)
                    .allowsHitTesting(false)
                PremiumPill()
                    .padding(Theme.Spacing.md)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
