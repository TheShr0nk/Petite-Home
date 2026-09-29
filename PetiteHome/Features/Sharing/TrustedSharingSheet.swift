import SwiftUI
import SwiftData

/// "Share with someone I trust" (premium): a read-only, time-limited link.
struct TrustedSharingSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var household: Household

    @State private var contact = Contact()
    @State private var access: TrustedAccessLevel = .viewFamilyFile
    @State private var expiryDays = 30
    @State private var working = false
    @State private var error: String?
    @State private var createdLink: URL?

    var body: some View {
        NavigationStack {
            EditorScroll(title: "Share with someone I trust") {
                if !entitlements.isPremium {
                    LockedPreview(onTap: { appState.showPaywall(.trustedSharing) }) { form }
                } else {
                    form
                }
                if let error { Text(error).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
                if let createdLink {
                    Card(background: Theme.Colors.powderBlueMist) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Link ready").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                            Text("Send it however you like. It stops working after \(expiryDays) days, or sooner if you revoke it.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                            ShareLink(item: createdLink) { Label("Send the link", systemImage: "square.and.arrow.up") }.buttonStyle(.primary)
                        }
                    }
                }
                let existing = (household.trustedContacts ?? []).filter { !$0.isExpired && $0.shareLink != nil }
                if !existing.isEmpty {
                    SectionHeader(title: "Who has a link")
                    ForEach(existing, id: \.uuid) { trusted in
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trusted.contact.name).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                    Text("\(trusted.accessLevel.label) · until \(trusted.expiresAt?.formatted(date: .abbreviated, time: .omitted) ?? "revoked")").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                                }
                                Spacer()
                                Button("Revoke") { revoke(trusted) }.font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                            }
                        }
                    }
                }
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("A grandparent, a sitter, the person you named as guardian. They get a read-only copy of the \(AppCopy.binderLower) that expires.")
                .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
            ContactEntry(contact: $contact, showRelationship: true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("What they can see").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                FlowLayout(spacing: Theme.Spacing.sm) {
                    ForEach(TrustedAccessLevel.allCases, id: \.rawValue) { level in
                        Chip(label: level.label, isSelected: access == level) { access = level }
                    }
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Link expires").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                FlowLayout(spacing: Theme.Spacing.sm) {
                    ForEach([7, 30, 90, 365], id: \.self) { d in Chip(label: d == 365 ? "1 year" : "\(d) days", isSelected: expiryDays == d) { expiryDays = d } }
                }
            }
            Button(working ? "Making the link" : "Make the link") { Task { await create() } }
                .buttonStyle(.primary(enabled: contact.isFilled && !working)).disabled(!contact.isFilled || working)
        }
    }

    private func create() async {
        guard let file = household.familyFile else { return }
        working = true; error = nil
        defer { working = false }
        var attachments: [PDFExporter.Attachment] = []
        if access == .viewFamilyFileAndVault {
            for doc in household.documents ?? [] { if let img = VaultStore.image(for: doc) { attachments.append(PDFExporter.Attachment(title: doc.title, image: img)) } }
        }
        let pdf = PDFExporter(household: household, file: file, tier: .clean, attachments: attachments).render()
        let expires = Calendar.current.date(byAdding: .day, value: expiryDays, to: Date())
        do {
            let result = try await TrustedShareService.shared.createShare(pdf: pdf, title: "Family File for \(contact.name)", recipientName: contact.name, expiresAt: expires)
            let trusted = TrustedContact(contact: contact, accessLevel: access, expiresAt: expires)
            trusted.shareLink = result.url
            trusted.shareRecordName = result.recordName
            household.trustedContacts?.append(trusted)
            try? context.save()
            createdLink = result.url
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func revoke(_ trusted: TrustedContact) {
        if let name = trusted.shareRecordName { Task { await TrustedShareService.shared.revoke(recordName: name) } }
        context.delete(trusted)
        try? context.save()
    }
}
