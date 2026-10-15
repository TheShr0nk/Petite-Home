import Foundation
import SwiftData

enum MealSlot: String, Codable, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
    var order: Int { MealSlot.allCases.firstIndex(of: self) ?? 0 }
    /// Rough time of day, so meals sort among calendar events on the agenda.
    var hour: Int {
        switch self {
        case .breakfast: return 7
        case .lunch: return 12
        case .snack: return 15
        case .dinner: return 18
        }
    }
}

/// A recipe in the household's box. Not sensitive, so the photo is stored
/// plainly (it still syncs through CloudKit as an asset).
@Model
final class Recipe {
    /// Stable identity that survives sync. SwiftData supplies `id`; never declare one on a model.
    var uuid: UUID = UUID()
    var title: String = ""
    var ingredients: [String] = []
    var steps: [String] = []
    var servings: Int = 4
    var minutes: Int = 30
    var notes: String = ""
    var tags: [String] = []
    var sourceURL: String = ""
    @Attribute(.externalStorage) var photo: Data? = nil
    var createdByAdultID: UUID? = nil
    var createdAt: Date = Date()
    var timesCooked: Int = 0
    var lastCookedAt: Date? = nil
    var isFavorite: Bool = false

    var household: Household? = nil
    @Relationship(deleteRule: .nullify, inverse: \PlannedMeal.recipe) var plannedMeals: [PlannedMeal]? = []

    init(title: String, ingredients: [String] = [], steps: [String] = [], servings: Int = 4, minutes: Int = 30) {
        self.title = title
        self.ingredients = ingredients
        self.steps = steps
        self.servings = servings
        self.minutes = minutes
    }

    var summary: String {
        var parts: [String] = []
        if minutes > 0 { parts.append("\(minutes) min") }
        if servings > 0 { parts.append("serves \(servings)") }
        return parts.joined(separator: " · ")
    }
}

/// One meal on one day. Either points at a recipe or is just a title ("Leftovers", "Takeout").
@Model
final class PlannedMeal {
    /// Stable identity that survives sync. SwiftData supplies `id`; never declare one on a model.
    var uuid: UUID = UUID()
    var date: Date = Date()
    var slotRaw: String = MealSlot.dinner.rawValue
    var title: String = ""
    var notes: String = ""
    var cookAdultID: UUID? = nil
    var createdAt: Date = Date()

    var recipe: Recipe? = nil
    var household: Household? = nil

    init(date: Date, slot: MealSlot, title: String = "", recipe: Recipe? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.slotRaw = slot.rawValue
        self.title = title
        self.recipe = recipe
    }

    var slot: MealSlot {
        get { MealSlot(rawValue: slotRaw) ?? .dinner }
        set { slotRaw = newValue.rawValue }
    }
    var displayTitle: String { recipe?.title ?? (title.isEmpty ? "Something" : title) }
}

/// The shopping list for a run of days: every ingredient from every planned
/// recipe, de-duplicated by name, in the order they first appear. Pure.
enum ShoppingList {
    struct Line: Identifiable, Hashable {
        let key: String
        let text: String
        let recipes: [String]
        var id: String { key }
    }

    static func lines(for meals: [PlannedMeal]) -> [Line] {
        var order: [String] = []
        var texts: [String: String] = [:]
        var sources: [String: [String]] = [:]
        for meal in meals.sorted(by: { $0.date < $1.date }) {
            guard let recipe = meal.recipe else { continue }
            for ingredient in recipe.ingredients {
                let key = mergeKey(for: ingredient)
                guard !key.isEmpty else { continue }
                if texts[key] == nil { order.append(key); texts[key] = ingredient.trimmingCharacters(in: .whitespaces) }
                if !(sources[key] ?? []).contains(recipe.title) { sources[key, default: []].append(recipe.title) }
            }
        }
        return order.map { Line(key: $0, text: texts[$0] ?? $0, recipes: sources[$0] ?? []) }
    }

    /// The merge key for a shopping-list line: `normalize`, then the last word
    /// singularised, so "1 onion" and "2 onions, diced" land on the same line.
    static func mergeKey(for ingredient: String) -> String {
        let name = normalize(ingredient)
        guard !name.isEmpty else { return name }
        var words = name.split(separator: " ").map(String.init)
        if let last = words.last { words[words.count - 1] = singularized(last) }
        return words.joined(separator: " ")
    }

    /// Conservative English singular of one word, for key matching only (the
    /// result is never shown). Trailing "s"/"es"/"ies" are handled; words ending
    /// in "ss" or "us" (cress, hummus, asparagus) and anything three letters or
    /// shorter are left alone.
    static func singularized(_ word: String) -> String {
        guard word.count > 3, word.hasSuffix("s"), !word.hasSuffix("ss"), !word.hasSuffix("us") else { return word }
        if word.hasSuffix("ies"), word.count > 4 { return String(word.dropLast(3)) + "y" }
        for suffix in ["ches", "shes", "xes", "zes", "oes"] where word.hasSuffix(suffix) {
            return String(word.dropLast(2))
        }
        return String(word.dropLast())
    }

    /// Lowercased, quantity and unit stripped from the front, so "2 cups flour" and "flour" collapse together.
    static func normalize(_ ingredient: String) -> String {
        var s = ingredient.lowercased().trimmingCharacters(in: .whitespaces)
        let units = ["cups", "cup", "tbsp", "tablespoons", "tablespoon", "tsp", "teaspoons", "teaspoon", "oz", "ounces", "ounce", "lb", "lbs", "pounds", "pound", "g", "kg", "ml", "l", "cloves", "clove", "cans", "can", "large", "small", "medium", "of"]
        var words = s.split(separator: " ").map(String.init)
        while let first = words.first, first.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789½¼¾⅓⅔/-.")) != nil, first.rangeOfCharacter(from: .letters) == nil {
            words.removeFirst()
        }
        while let first = words.first, units.contains(first.trimmingCharacters(in: .punctuationCharacters)) {
            words.removeFirst()
        }
        s = words.joined(separator: " ")
        if let comma = s.firstIndex(of: ",") { s = String(s[..<comma]) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
