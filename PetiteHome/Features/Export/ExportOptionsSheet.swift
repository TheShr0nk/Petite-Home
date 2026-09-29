import SwiftUI
import SwiftData

/// Export options. Free: PDF with the footer. Premium: the clean export with
/// the sealed-envelope cover and vault appendix.
struct ExportOptionsSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    let household: Household
    @State private var rendered: PDFFile?
    @State private var rendering = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text("A printable copy for the fridge, the safe, or whoever's holding the fort.")
                    .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Family File").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                        Text("Every section. Carries a small “Made with Petite Home” footer.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        Button(rendering ? "Preparing" : "Export PDF") { render(.free) }.buttonStyle(.primary).disabled(rendering)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack { Text("Sealed envelope").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink); Spacer(); if !entitlements.isPremium { PremiumPill() } }
                        Text("No footer, dated cover page, and your vault documents as an appendix.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        Button("Export sealed copy") {
                            if entitlements.isPremium { render(.clean) } else { appState.showPaywall(.cleanExport) }
                        }.buttonStyle(.outline).disabled(rendering)
                    }
                }
                Spacer()
            }
            .padding(Theme.Spacing.gutter)
            .screenBackground()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { DoneToolbarItem() }
            .sheet(item: $rendered) { file in
                ShareSheet(items: [file.url])
            }
        }
        .presentationBackground(Theme.Colors.cream)
    }

    private func render(_ tier: PDFExporter.Tier) {
        guard let file = household.familyFile else { return }
        rendering = true
        var attachments: [PDFExporter.Attachment] = []
        if tier == .clean {
            for doc in household.documents ?? [] {
                if let image = VaultStore.image(for: doc) { attachments.append(PDFExporter.Attachment(title: doc.title, image: image)) }
            }
        }
        let data = PDFExporter(household: household, file: file, tier: tier, attachments: attachments).render()
        let url = FileManager.default.temporaryDirectory.appending(path: "Family File.pdf")
        try? data.write(to: url, options: .atomic)
        rendered = PDFFile(url: url)
        rendering = false
    }
}

struct PDFFile: Identifiable { let id = UUID(); let url: URL }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// What a trusted person or partner sees when they open a shared link.
struct SharedFileViewer: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let pdf: Data
    var body: some View {
        NavigationStack {
            PDFPreview(data: pdf)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { DoneToolbarItem() }
        }
    }
}
