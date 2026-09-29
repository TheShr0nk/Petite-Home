import Foundation
import SwiftData
import UIKit

/// Writes and reads vault documents. Everything is sealed before it touches
/// the model, so the CloudKit asset is ciphertext.
enum VaultStore {
    @discardableResult
    static func save(image: UIImage, title: String, category: VaultCategory, household: Household, context: ModelContext,
                     linkedChild: Child? = nil, linkedAdult: Adult? = nil, expiresOn: Date? = nil) -> VaultDocument? {
        guard let jpeg = image.jpegData(compressionQuality: 0.85) else { return nil }
        return save(data: jpeg, mimeType: "image/jpeg", title: title, category: category, household: household, context: context,
                    linkedChild: linkedChild, linkedAdult: linkedAdult, expiresOn: expiresOn)
    }

    @discardableResult
    static func save(data: Data, mimeType: String, title: String, category: VaultCategory, household: Household, context: ModelContext,
                     linkedChild: Child? = nil, linkedAdult: Adult? = nil, expiresOn: Date? = nil) -> VaultDocument? {
        guard let sealed = try? VaultCrypto.shared.seal(data) else { return nil }
        let doc = VaultDocument(title: title, category: category)
        doc.encryptedAsset = sealed
        doc.mimeType = mimeType
        doc.keyIdentifier = VaultCrypto.currentKeyIdentifier
        doc.linkedChild = linkedChild
        doc.linkedAdult = linkedAdult
        doc.expiresOn = expiresOn
        household.documents?.append(doc)
        try? context.save()
        return doc
    }

    static func open(_ doc: VaultDocument) -> Data? {
        guard let sealed = doc.encryptedAsset else { return nil }
        return try? VaultCrypto.shared.open(sealed)
    }

    static func image(for doc: VaultDocument) -> UIImage? {
        guard doc.mimeType.hasPrefix("image"), let data = open(doc) else { return nil }
        return UIImage(data: data)
    }
}
