import Foundation

/// Pulls a recipe out of a web page. Most recipe sites, and the recipe cards
/// people post from blogs to Instagram and TikTok captions, carry schema.org
/// Recipe JSON-LD; that is what we read. Falls back to the page title.
enum RecipeImporter {
    struct Draft: Equatable {
        var title = ""
        var ingredients: [String] = []
        var steps: [String] = []
        var servings = 4
        var minutes = 0
        var sourceURL = ""
        var imageURL: String? = nil
        var isEmpty: Bool { title.isEmpty && ingredients.isEmpty && steps.isEmpty }
    }

    enum ImportError: LocalizedError {
        case badURL, nothingFound
        var errorDescription: String? {
            switch self {
            case .badURL: return "That doesn't look like a link."
            case .nothingFound: return "Couldn't find a recipe on that page. You can still type it in."
            }
        }
    }

    static func fetch(_ raw: String) async throws -> Draft {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed.hasPrefix("http") ? trimmed : "https://\(trimmed)"), url.host != nil else { throw ImportError.badURL }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone) PetiteHome/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(decoding: data, as: UTF8.self)
        var draft = parse(html: html)
        draft.sourceURL = url.absoluteString
        if draft.isEmpty { throw ImportError.nothingFound }
        return draft
    }

    /// Pure, so the tests can feed it HTML.
    static func parse(html: String) -> Draft {
        var draft = Draft()
        for block in jsonLDBlocks(in: html) {
            guard let data = block.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: data) else { continue }
            if let recipe = findRecipe(in: json) {
                draft.title = decodeEntities(recipe["name"] as? String ?? "")
                draft.ingredients = (recipe["recipeIngredient"] as? [String] ?? []).map { decodeEntities($0).trimmingCharacters(in: .whitespaces) }
                draft.steps = instructions(from: recipe["recipeInstructions"]).map(decodeEntities)
                draft.servings = servings(from: recipe["recipeYield"]) ?? 4
                draft.minutes = minutes(fromISO8601: recipe["totalTime"] as? String)
                    ?? ((minutes(fromISO8601: recipe["prepTime"] as? String) ?? 0) + (minutes(fromISO8601: recipe["cookTime"] as? String) ?? 0))
                if let image = recipe["image"] as? String { draft.imageURL = image }
                else if let images = recipe["image"] as? [String] { draft.imageURL = images.first }
                else if let obj = recipe["image"] as? [String: Any] { draft.imageURL = obj["url"] as? String }
                if draft.minutes == 0 { draft.minutes = 30 }
                return draft
            }
        }
        // Fallback: the page title, so the user has something to edit.
        if let title = firstCapture(#"<meta[^>]*property=["']og:title["'][^>]*content=["']([^"']*)["']"#, in: html)
            ?? firstCapture(#"<title[^>]*>([^<]*)</title>"#, in: html) {
            draft.title = decodeEntities(title)
        }
        return draft
    }

    private static func firstCapture(_ pattern: String, in html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let ns = html as NSString
        guard let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)), match.numberOfRanges > 1 else { return nil }
        return ns.substring(with: match.range(at: 1))
    }

    private static func jsonLDBlocks(in html: String) -> [String] {
        let pattern = #"<script[^>]*type=["']application/ld\+json["'][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return [] }
        let ns = html as NSString
        return regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).map { ns.substring(with: $0.range(at: 1)) }
    }

    /// Recipes hide in @graph arrays and nested objects; walk until one turns up.
    private static func findRecipe(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            let type = dict["@type"]
            if (type as? String) == "Recipe" || (type as? [String])?.contains("Recipe") == true { return dict }
            for value in dict.values { if let found = findRecipe(in: value) { return found } }
        } else if let array = json as? [Any] {
            for value in array { if let found = findRecipe(in: value) { return found } }
        }
        return nil
    }

    private static func instructions(from value: Any?) -> [String] {
        if let text = value as? String {
            return text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        }
        guard let list = value as? [Any] else { return [] }
        var out: [String] = []
        for item in list {
            if let s = item as? String { out.append(s) }
            else if let d = item as? [String: Any] {
                if let text = d["text"] as? String { out.append(text) }
                else if let steps = d["itemListElement"] { out.append(contentsOf: instructions(from: steps)) }
            }
        }
        return out.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func servings(from value: Any?) -> Int? {
        let text: String
        if let s = value as? String { text = s } else if let n = value as? Int { return n } else if let a = value as? [Any], let f = a.first { return servings(from: f) } else { return nil }
        let digits = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        return digits.first
    }

    /// PT1H30M → 90.
    static func minutes(fromISO8601 value: String?) -> Int? {
        guard let value, value.hasPrefix("P") else { return nil }
        var total = 0
        var number = ""
        var inTime = false
        for ch in value.dropFirst() {
            if ch == "T" { inTime = true; continue }
            if ch.isNumber || ch == "." { number.append(ch); continue }
            let n = Double(number) ?? 0
            number = ""
            switch ch {
            case "D": total += Int(n * 1440)
            case "H": total += Int(n * 60)
            case "M": total += inTime ? Int(n) : Int(n * 43200)
            default: break
            }
        }
        return total > 0 ? total : nil
    }

    private static func decodeEntities(_ s: String) -> String {
        var out = s
        let map = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " ", "&#8217;": "’", "&#8220;": "“", "&#8221;": "”"]
        for (k, v) in map { out = out.replacingOccurrences(of: k, with: v) }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
