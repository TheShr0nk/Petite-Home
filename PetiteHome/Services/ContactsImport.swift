import SwiftUI
import Contacts
import ContactsUI

/// Wraps CNContactPickerViewController. The picker runs out of process and hands
/// back only the contact the user chose, so no Contacts permission is requested.
/// `requestAccess` stays for a future "import everyone" feature.
struct ContactPicker: UIViewControllerRepresentable {
    var onPick: (Contact) -> Void

    static func requestAccess() async -> Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            return (try? await CNContactStore().requestAccess(for: .contacts)) ?? false
        case .denied, .restricted:
            return false
        default:
            return true
        }
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [CNContactPhoneNumbersKey, CNContactEmailAddressesKey, CNContactPostalAddressesKey]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, CNContactPickerDelegate {
        let onPick: (Contact) -> Void
        init(onPick: @escaping (Contact) -> Void) { self.onPick = onPick }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onPick(Contact(from: contact))
        }
    }
}

extension Contact {
    init(from cn: CNContact) {
        self.init()
        name = CNContactFormatter.string(from: cn, style: .fullName) ?? [cn.givenName, cn.familyName].joined(separator: " ")
        if name.isEmpty { name = cn.organizationName }
        phone = cn.phoneNumbers.first?.value.stringValue ?? ""
        email = (cn.emailAddresses.first?.value as String?) ?? ""
        if let postal = cn.postalAddresses.first?.value {
            address = CNPostalAddressFormatter.string(from: postal, style: .mailingAddress).replacingOccurrences(of: "\n", with: ", ")
        }
    }
}
