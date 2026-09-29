import SwiftUI

/// Petite Picks: product picks and reorders. Free, never gated.
/// Mirrors the website's affiliate list: a pick without a URL renders as plain
/// text until the affiliate account is approved. Only things Casey has used
/// with her own kid go here.
struct Pick: Identifiable {
    let id: String
    let name: String
    let note: String
    let url: URL?
    let isPetiteHome: Bool
}

enum PicksCatalog {
    static let ours: [Pick] = [
        Pick(id: "petite-powder", name: "Petite Powder", note: "Fragrance-free laundry powder for babies and kids. Reserve a bag from the first 500.", url: URL(string: "https://petitehome.co/products/petite-powder"), isPetiteHome: true),
        Pick(id: "dryer-balls", name: "Wool dryer balls", note: "Six, undyed. Skip the sheets.", url: URL(string: "https://petitehome.co/products/dryer-balls"), isPetiteHome: true),
        Pick(id: "laundry-reset", name: "Laundry reset", note: "Strip the build-up out of the clothes you already own.", url: URL(string: "https://petitehome.co/products/laundry-reset"), isPetiteHome: true),
    ]
    /// Keys match 02-web/src/content/affiliates.ts. URLs stay empty until approved.
    static let picks: [Pick] = [
        Pick(id: "nursing-pillow", name: "Nursing pillow", note: "The one that actually stays put.", url: nil, isPetiteHome: false),
        Pick(id: "robe-ekouaer", name: "Ekouaer robe", note: "For the first two weeks, when you live in it.", url: nil, isPetiteHome: false),
        Pick(id: "stroller-fan", name: "Clip-on stroller fan", note: "Summer naps on the go.", url: nil, isPetiteHome: false),
        Pick(id: "electrolyte-packets", name: "Electrolyte packets", note: "For you, not the baby.", url: nil, isPetiteHome: false),
        Pick(id: "silverettes", name: "Silverettes", note: "Ask a nurse. Then buy them.", url: nil, isPetiteHome: false),
        Pick(id: "button-up-pajamas", name: "Button-up pajamas", note: "Zippers wake them up. Buttons don't.", url: nil, isPetiteHome: false),
        Pick(id: "triple-paste", name: "Triple Paste", note: "The diaper cream that works when the others didn't.", url: nil, isPetiteHome: false),
    ]
}

struct PicksView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                Text("What we use, what we skipped, and why. Nothing here is sponsored. Some links pay us a small amount at no cost to you.")
                    .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep).fixedSize(horizontal: false, vertical: true)
                SectionHeader(title: "From Petite Home Co.")
                VStack(spacing: Theme.Spacing.sm) { ForEach(PicksCatalog.ours) { PickRow(pick: $0) } }
                SectionHeader(title: "Casey's picks")
                VStack(spacing: Theme.Spacing.sm) { ForEach(PicksCatalog.picks) { PickRow(pick: $0) } }
                Link("Affiliate disclosure", destination: URL(string: "https://petitehome.co/affiliate-disclosure")!)
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            }
            .padding(.horizontal, Theme.Spacing.gutter).padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Picks")
        .toolbar { SettingsToolbarItem() }
    }
}

struct PickRow: View {
    @Environment(\.openURL) private var openURL
    let pick: Pick
    var body: some View {
        Button {
            if let url = pick.url { openURL(url) }
        } label: {
            Card(background: pick.isPetiteHome ? Theme.Colors.powderBlueMist : Theme.Colors.creamDeep) {
                HStack(spacing: Theme.Spacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(pick.name).font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.ink)
                        Text(pick.note).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if pick.url != nil {
                        Image(systemName: "arrow.up.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep)
                    } else {
                        Text("Soon").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(pick.url == nil)
    }
}
