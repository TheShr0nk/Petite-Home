import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers
import LocalAuthentication

/// The vault (premium). Free users see three greyed sample cards and the paywall on tap.
struct VaultView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Bindable var household: Household
    @State private var showAdd = false
    @State private var unlocked = false

    private var documents: [VaultDocument] { (household.documents ?? []).sorted { $0.addedAt > $1.addedAt } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if !entitlements.isPremium {
                    Text("Birth certificates, Social Security cards, passports. Encrypted on your phone before they sync, so only you can open them.")
                        .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                    LockedPreview(onTap: { appState.showPaywall(.vault) }) {
                        VStack(spacing: Theme.Spacing.md) {
                            sampleCard("Theo's birth certificate", .birthCert)
                            sampleCard("Social Security card", .ssnCard)
                            sampleCard("Passport", .passport, expires: "Expires in 14 months")
                        }
                    }
                } else if !unlocked {
                    VStack(spacing: Theme.Spacing.lg) {
                        BrandIcon(systemName: "lock.doc", isActive: true, size: 40)
                        Text("Open with Face ID").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                        Button("Open the vault") { authenticate() }.buttonStyle(.primary)
                    }
                    .frame(maxWidth: .infinity).padding(.top, 60)
                } else {
                    if documents.isEmpty {
                        EmptyStateRow(instruction: "Add the first document. A photo of a birth certificate is a good start.", systemImage: "doc.badge.plus") { showAdd = true }
                    }
                    ForEach(documents) { doc in
                        NavigationLink(value: doc) { DocumentCard(doc: doc) }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle("Vault")
        .toolbar {
            SettingsToolbarItem()
            if entitlements.isPremium && unlocked {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus").foregroundStyle(Theme.Colors.powderBlueDk) }.accessibilityLabel("Add a document")
                }
            }
        }
        .navigationDestination(for: VaultDocument.self) { doc in DocumentDetailView(doc: doc) }
        .sheet(isPresented: $showAdd) { AddDocumentSheet(household: household) }
        .onAppear { if entitlements.isPremium && !unlocked { authenticate() } }
    }

    private func authenticate() {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { unlocked = true; return }
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "To open your vault") { ok, _ in
            DispatchQueue.main.async { unlocked = ok }
        }
    }

    private func sampleCard(_ title: String, _ category: VaultCategory, expires: String? = nil) -> some View {
        Card {
            HStack(spacing: Theme.Spacing.md) {
                BrandIcon(systemName: category.systemImage, size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                    Text(expires ?? category.label).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                Spacer()
            }
        }
    }
}

struct DocumentCard: View {
    let doc: VaultDocument
    var body: some View {
        Card {
            HStack(spacing: Theme.Spacing.md) {
                BrandIcon(systemName: doc.category.systemImage, isActive: true, size: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(doc.category.label)
                        if let who = doc.linkedName { Text("· \(who)") }
                        if let exp = doc.expiresOn {
                            let days = Calendar.current.dateComponents([.day], from: Date(), to: exp).day ?? 0
                            Text(days < 0 ? "· expired" : "· expires in \(days) days").foregroundStyle(days < 0 ? Theme.Colors.danger : (days <= 60 ? Theme.Colors.warn : Theme.Colors.sandDeep))
                        }
                    }
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep)
            }
        }
    }
}

struct DocumentDetailView: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var doc: VaultDocument
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let image = VaultStore.image(for: doc) {
                    Image(uiImage: image).resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                } else if doc.mimeType == "application/pdf", let data = VaultStore.open(doc) {
                    PDFPreview(data: data).frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                } else {
                    Text("This document couldn't be opened on this device.").font(Typography.body).foregroundStyle(Theme.Colors.danger)
                }
                LabeledField(label: "Title", text: $doc.title, placeholder: "Title", autocapitalization: .sentences)
                RenewalRow(label: "Expires", date: $doc.expiresOn, remindersEnabled: $doc.remindersEnabled, household: doc.household)
                if let data = VaultStore.open(doc) {
                    ShareLink(item: VaultShareFile(data: data, title: doc.title, mimeType: doc.mimeType), preview: SharePreview(doc.title)) {
                        Label("Share a copy", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.outline)
                }
                Button("Delete from vault", role: .destructive) { confirmDelete = true }
                    .font(Typography.button).foregroundStyle(Theme.Colors.danger).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.Spacing.gutter).padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle(doc.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this document?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                NotificationService.shared.cancelExpiration(id: doc.id)
                context.delete(doc); try? context.save(); dismiss()
            }
        }
        .onDisappear {
            try? context.save()
            if let h = doc.household { ExpirationScheduler.sync(household: h, isPremium: entitlements.isPremium) }
        }
    }
}

struct VaultShareFile: Transferable {
    let data: Data
    let title: String
    let mimeType: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { $0.data }
            .suggestedFileName { $0.title }
    }
}

struct PDFPreview: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(data: data)
        view.autoScales = true
        view.backgroundColor = UIColor(hex: 0xF2E7D8)
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}

/// Add a document from the camera, the photo library, or a PDF file. Gated on save.
struct AddDocumentSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let household: Household

    @State private var title = ""
    @State private var category: VaultCategory = .birthCert
    @State private var image: UIImage?
    @State private var pdfData: Data?
    @State private var linkedChildID: UUID?
    @State private var linkedAdultID: UUID?
    @State private var expiresOn: Date?
    @State private var remind = false
    @State private var showCamera = false
    @State private var showFiles = false

    var body: some View {
        NavigationStack {
            EditorScroll(title: "Add a document") {
                HStack(spacing: Theme.Spacing.sm) {
                    Button { showCamera = true } label: { Label("Camera", systemImage: "camera") }.buttonStyle(.outline)
                    Button { showFiles = true } label: { Label("PDF file", systemImage: "doc") }.buttonStyle(.outline)
                }
                if let image {
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                } else if pdfData != nil {
                    Label("PDF ready", systemImage: "checkmark.circle").font(Typography.body).foregroundStyle(Theme.Colors.success)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("What is it").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach(VaultCategory.allCases) { c in
                            Chip(label: c.label, isSelected: c == category) { category = c; if title.isEmpty { title = c.label } }
                        }
                    }
                }
                LabeledField(label: "Title", text: $title, placeholder: category.label, autocapitalization: .sentences)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Whose").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        Chip(label: "The household", isSelected: linkedChildID == nil && linkedAdultID == nil) { linkedChildID = nil; linkedAdultID = nil }
                        ForEach(household.kids) { c in Chip(label: c.displayName, isSelected: linkedChildID == c.id) { linkedChildID = c.id; linkedAdultID = nil } }
                        ForEach(household.adults) { a in Chip(label: a.displayName, isSelected: linkedAdultID == a.id) { linkedAdultID = a.id; linkedChildID = nil } }
                    }
                }
                RenewalRow(label: "Expires", date: $expiresOn, remindersEnabled: $remind, household: household)
                Button {
                    guard entitlements.isPremium else { appState.showPaywall(.vaultSave); return }
                    save()
                } label: {
                    HStack { Text("Save to vault"); if !entitlements.isPremium { PremiumPill() } }
                }
                .buttonStyle(.primary(enabled: image != nil || pdfData != nil)).disabled(image == nil && pdfData == nil)
                Text("Encrypted on this phone before it syncs. Nobody at Petite Home can read it.")
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { picked in showCamera = false; if let picked { image = picked; pdfData = nil } }.ignoresSafeArea()
        }
        .fileImporter(isPresented: $showFiles, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result, url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                pdfData = try? Data(contentsOf: url); image = nil
                if title.isEmpty { title = url.deletingPathExtension().lastPathComponent }
            }
        }
    }

    private func save() {
        let child = household.kids.first { $0.id == linkedChildID }
        let adult = household.adults.first { $0.id == linkedAdultID }
        let finalTitle = title.isEmpty ? category.label : title
        var saved: VaultDocument?
        if let image {
            saved = VaultStore.save(image: image, title: finalTitle, category: category, household: household, context: context, linkedChild: child, linkedAdult: adult, expiresOn: expiresOn)
        } else if let pdfData {
            saved = VaultStore.save(data: pdfData, mimeType: "application/pdf", title: finalTitle, category: category, household: household, context: context, linkedChild: child, linkedAdult: adult, expiresOn: expiresOn)
        }
        saved?.remindersEnabled = remind
        try? context.save()
        ExpirationScheduler.sync(household: household, isPremium: entitlements.isPremium)
        dismiss()
    }
}
