import SwiftUI
import SwiftData

/// "Share with someone I trust": a read-only link. Standing (never expires,
/// keeps itself current) for the guardian; time-limited for a sitter or a visit.
struct TrustedSharingSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var household: Household

    @State private var contact = Contact()
    @State private var access: TrustedAccessLevel = .viewFamilyFile
    @State private var expiryDays = 30
    @State private var standing = true
    @State private var working = false
    @State private var error: String?
    @State private var createdLink: URL?
    @State private var showPaper = false
    @State private var refreshing: UUID?

    var body: some View {
        NavigationStack {
            EditorScroll(title: "Share with someone I trust") {
                if !entitlements.isPremium {
                    LockedPreview(gate: .trustedSharing, onTap: { appState.showPaywall(.trustedSharing) }) { form }
                } else {
                    form
                }
                if let error { Text(error).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
                if let createdLink {
                    Card(background: Theme.Colors.powderBlueMist) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Link ready").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                            Text(standing ? "Send it once. It never expires, and the copy behind it updates itself whenever you change the file. Revoke it here any time."
                                          : "Send it however you like. It stops working after \(expiryDays) days, or sooner if you revoke it.")
                                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
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
                                    Text(trusted.isStanding
                                         ? "\(trusted.accessLevel.label) · keeps itself current · updated \(trusted.lastRefreshedAt?.formatted(date: .abbreviated, time: .omitted) ?? "just now")"
                                         : "\(trusted.accessLevel.label) · until \(trusted.expiresAt?.formatted(date: .abbreviated, time: .omitted) ?? "revoked")")
                                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                                    if trusted.isStanding {
                                        Button(refreshing == trusted.uuid ? "Updating" : "Update now") { refresh(trusted) }
                                            .font(Typography.caption).foregroundStyle(Theme.Colors.accentText).disabled(refreshing != nil)
                                    }
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
            .sheet(isPresented: $showPaper) { ExportOptionsSheet(household: household) }
            .onAppear {
                // The guardian is the person this is for. Start there.
                if !contact.isFilled, let guardian = household.familyFile?.designatedGuardian, guardian.isFilled,
                   !(household.trustedContacts ?? []).contains(where: { $0.contact.name == guardian.name && $0.shareLink != nil }) {
                    contact = guardian
                }
            }
        }
        .presentationBackground(Theme.Colors.cream)
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("The person you named as guardian should have this before anything happens. A read-only copy they can open from any iPhone, kept current by your phone.")
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
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text("How long").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                SelectableRow(title: "Keeps itself current", detail: "Never expires. Updates whenever you change the file. For the guardian.",
                              systemImage: "arrow.triangle.2.circlepath", isSelected: standing) { standing = true }
                SelectableRow(title: "For a while", detail: "A sitter, a trip, a hospital stay. Stops working on its own.",
                              systemImage: "clock", isSelected: !standing) { standing = false }
                if !standing {
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach([7, 30, 90, 365], id: \.self) { d in Chip(label: d == 365 ? "1 year" : "\(d) days", isSelected: expiryDays == d) { expiryDays = d } }
                    }
                }
            }
            Button(working ? "Making the link" : "Make the link") { Task { await create() } }
                .buttonStyle(.primary(enabled: contact.isFilled && !working)).disabled(!contact.isFilled || working)
            Card {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Paper doesn't need a phone").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                    Text(PrintOrderService.isAvailable ? "Print the sealed copy for the guardian's drawer, or have a bound binder printed and mailed." : "Print the sealed copy for the guardian's drawer.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    Button { showPaper = true } label: { Label(PrintOrderService.isAvailable ? "Print or order a binder" : "Print a copy", systemImage: "printer") }.buttonStyle(.outline)
                }
            }
        }
    }

    private func refresh(_ trusted: TrustedContact) {
        refreshing = trusted.uuid
        Task {
            await StandingLinkRefresher.refreshIfNeeded(household: household, context: context, force: true)
            refreshing = nil
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
        let expires = standing ? nil : Calendar.current.date(byAdding: .day, value: expiryDays, to: Date())
        do {
            let result = try await TrustedShareService.shared.createShare(pdf: pdf, title: "Family File for \(contact.name)", recipientName: contact.name, expiresAt: expires)
            let trusted = TrustedContact(contact: contact, accessLevel: access, expiresAt: expires)
            trusted.isStanding = standing
            trusted.lastRefreshedAt = Date()
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
