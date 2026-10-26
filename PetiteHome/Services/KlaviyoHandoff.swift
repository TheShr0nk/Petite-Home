import Foundation

/// After Sign in with Apple, if the user shared their email, subscribe them
/// to the same Klaviyo list as the website through the site's own endpoint.
/// The endpoint is `POST https://petitehome.co/api/subscribe`, the route every
/// form on the site posts to. If the email was hidden, this is never called.
///
/// The site accepts a fixed set of placements; `app` is the one it has for
/// this app (`02-web/src/app/api/subscribe/route.ts`). Anything else records
/// as `unknown`. The `source` key is sent as well for the profile property.
enum KlaviyoHandoff {
    static let endpoint = URL(string: "https://petitehome.co/api/subscribe")!

    static func subscribe(email: String, youngestChildAge: AgeSegment?) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed.contains("@"), !trimmed.hasSuffix("privaterelay.appleid.com") else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "email": trimmed,
            "kind": "family-file",
            "placement": "app",
            "source": "ios_app",
        ]
        body["youngestChildAge"] = (youngestChildAge ?? .oneToFour).rawValue
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        // Best effort. A failure here is silent; the app never blocks on marketing.
        _ = try? await URLSession.shared.data(for: request)
    }
}
