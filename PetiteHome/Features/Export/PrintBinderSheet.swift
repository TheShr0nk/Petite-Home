import SwiftUI
import SwiftData
import SafariServices
import PDFKit

/// Order a printed, bound copy of the Family File. The app renders the sealed
/// PDF, the website takes payment and shipping details and sends it to print.
struct PrintBinderSheet: View {
    @Environment(\.dismiss) private var dismiss
    let household: Household
    @State private var quote: PrintOrderService.Quote?
    @State private var includeVault = false
    @State private var working = false
    @State private var error: String?
    @State private var checkout: URL?
    @State private var sent = false

    var body: some View {
        NavigationStack {
            EditorScroll(title: "A printed binder") {
                Text("The sealed copy of your Family File, bound with a tab for each section, printed and mailed. For the drawer at home, or straight to the guardian.")
                    .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        row("What's in it", "Every section, the dated cover, no footer.")
                        row("Price", quote?.price ?? "Shown at checkout")
                        row("Shipping", quote?.shipping ?? "Shown at checkout")
                        row("Arrives in", quote.map { "\($0.days) days" } ?? "About two weeks")
                    }
                }
                Toggle(isOn: $includeVault) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Include the vault documents").font(Typography.body).foregroundStyle(Theme.Colors.ink)
                        Text("Birth certificates and cards as an appendix. Only if the binder will live somewhere locked.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    }
                }
                .tint(Theme.Colors.accentText)
                if let error { Text(error).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
                if sent {
                    Card(background: Theme.Colors.powderBlueMist) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("If you finished checkout, it's on its way.").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                            Text("The receipt and tracking come by email. The copy we printed is the file as of right now; order again after big changes.")
                                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        }
                    }
                }
                Button(working ? "Preparing your file" : "Continue to checkout") { Task { await order() } }
                    .buttonStyle(.primary(enabled: !working)).disabled(working)
                Text("Checkout opens on petitehome.co. Your address and card never pass through the app.")
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
            .task { quote = await PrintOrderService.quote() }
            .fullScreenCover(item: Binding(get: { checkout.map(WebPage.init) }, set: { if $0 == nil { checkout = nil } })) { page in
                SafariView(url: page.url).ignoresSafeArea()
            }
        }
        .presentationBackground(Theme.Colors.cream)
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(Typography.label).foregroundStyle(Theme.Colors.sandDeep).frame(width: 90, alignment: .leading)
            Text(value).font(Typography.body).foregroundStyle(Theme.Colors.ink)
        }
    }

    private func order() async {
        guard let file = household.familyFile else { return }
        working = true; error = nil
        defer { working = false }
        var attachments: [PDFExporter.Attachment] = []
        if includeVault {
            for doc in household.documents ?? [] {
                if let image = VaultStore.image(for: doc) { attachments.append(PDFExporter.Attachment(title: doc.title, image: image)) }
            }
        }
        let pdf = PDFExporter(household: household, file: file, tier: .clean, attachments: attachments).render()
        let pages = PDFDocument(data: pdf)?.pageCount ?? 0
        do {
            let created = try await PrintOrderService.createOrder(pdf: pdf, title: "\(household.displayName) Family File", pages: pages, includeVault: includeVault)
            Analytics.track(.pdfExported, ["kind": "binder_order", "orderId": created.orderId])
            checkout = created.checkoutUrl
            sent = true
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct WebPage: Identifiable { let url: URL; var id: String { url.absoluteString } }

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = Theme.Colors.uiAccentText
        return vc
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
