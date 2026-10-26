import Foundation

/// Ordering a printed, bound Family File. The app renders the PDF and hands it
/// to the website, which charges the card and sends the job to the print
/// vendor. Physical goods can't go through in-app purchase, so the checkout is
/// a web page opened from the app (App Review guideline 3.1.3(e)).
///
/// Website contract, both on petitehome.co (see docs/print-binder.md):
///   GET  /api/print-orders/quote        -> { "price": "$49", "shipping": "Free in the US", "days": "7 to 10" }
///   POST /api/print-orders  (multipart)  -> { "checkoutUrl": "https://checkout.stripe.com/...", "orderId": "po_..." }
///        fields: file (application/pdf), title, pages, includeVault ("true"/"false"), source ("ios_app")
enum PrintOrderService {
    /// Off until the website ships the two routes above. While off, the export
    /// sheet hides the binder card and the entry points stop mentioning one;
    /// flip to true when `GET /api/print-orders/quote` returns 200 in production.
    static let isAvailable = false

    static let base = URL(string: "https://petitehome.co/api/print-orders")!

    struct Quote: Decodable { var price: String; var shipping: String; var days: String }
    struct Created: Decodable { var checkoutUrl: URL; var orderId: String }

    enum OrderError: LocalizedError {
        case unavailable, server(String)
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Ordering isn't available right now. The PDF still exports, and you can print it anywhere."
            case .server(let s): return s
            }
        }
    }

    static func quote() async -> Quote? {
        guard let (data, response) = try? await URLSession.shared.data(from: base.appending(path: "quote")),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(Quote.self, from: data)
    }

    static func createOrder(pdf: Data, title: String, pages: Int, includeVault: Bool) async throws -> Created {
        var request = URLRequest(url: base)
        request.httpMethod = "POST"
        let boundary = "PetiteHome-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".data(using: .utf8)!)
        }
        field("title", title); field("pages", String(pages)); field("includeVault", includeVault ? "true" : "false"); field("source", "ios_app")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"family-file.pdf\"\r\nContent-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdf)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: request) } catch { throw OrderError.unavailable }
        guard let http = response as? HTTPURLResponse else { throw OrderError.unavailable }
        guard (200...299).contains(http.statusCode) else {
            if let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String { throw OrderError.server(message) }
            throw OrderError.unavailable
        }
        do { return try JSONDecoder().decode(Created.self, from: data) } catch { throw OrderError.unavailable }
    }
}
