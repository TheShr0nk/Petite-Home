import Foundation
import SwiftData

/// Keeps standing trusted-person links current. A standing link never expires;
/// instead the PDF behind it is re-rendered and re-uploaded whenever the Family
/// File has changed since the last upload. Runs on launch, on foreground, and
/// a minute after an edit so a burst of edits becomes one upload.
@MainActor
enum StandingLinkRefresher {
    private static var pending: Task<Void, Never>?

    /// Re-uploads every standing link whose copy is older than the file's last change.
    static func refreshIfNeeded(household: Household, context: ModelContext, force: Bool = false) async {
        guard let file = household.familyFile else { return }
        let standing = (household.trustedContacts ?? []).filter { $0.isStanding && $0.shareRecordName != nil }
        guard !standing.isEmpty else { return }
        for trusted in standing {
            let stale = force || trusted.lastRefreshedAt.map { $0 < file.updatedAt } ?? true
            guard stale, let name = trusted.shareRecordName else { continue }
            var attachments: [PDFExporter.Attachment] = []
            if trusted.accessLevel == .viewFamilyFileAndVault {
                for doc in household.documents ?? [] {
                    if let image = VaultStore.image(for: doc) { attachments.append(PDFExporter.Attachment(title: doc.title, image: image)) }
                }
            }
            let pdf = PDFExporter(household: household, file: file, tier: .clean, attachments: attachments).render()
            do {
                try await TrustedShareService.shared.refresh(recordName: name, pdf: pdf)
                trusted.lastRefreshedAt = Date()
            } catch {
                // Offline or iCloud hiccup: the next launch tries again. The old copy stays readable.
            }
        }
        try? context.save()
    }

    /// Called after an edit. Waits a minute of quiet, then refreshes once.
    static func scheduleAfterEdit(household: Household, context: ModelContext) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled else { return }
            await refreshIfNeeded(household: household, context: context)
        }
    }
}
