import SwiftUI
import CloudKit
import UIKit

struct SharePayload: Identifiable {
    let id = UUID()
    let share: CKShare
    let container: CKContainer
}

/// The native CKShare sheet, presented for partner invites.
struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        CloudSharingService.shared.makeSharingController(share: share, container: container)
    }
    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}
