import Foundation
import AuthenticationServices

/// Sign in with Apple. Identity only: CloudKit already uses the iCloud
/// account, so there is no email/password screen anywhere in the app.
enum AppleSignIn {
    struct Result {
        let userID: String
        let email: String?
        let fullName: PersonNameComponents?
    }

    static func handle(_ authorization: ASAuthorization) -> Result? {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return nil }
        KeychainService.shared.setString(credential.user, for: .appleUserID)
        return Result(userID: credential.user, email: credential.email, fullName: credential.fullName)
    }

    static var storedUserID: String? { KeychainService.shared.string(for: .appleUserID) }

    /// Checks whether the stored credential is still valid (revoked credentials sign the user out).
    static func credentialState() async -> ASAuthorizationAppleIDProvider.CredentialState {
        guard let id = storedUserID else { return .notFound }
        return (try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: id)) ?? .notFound
    }
}
