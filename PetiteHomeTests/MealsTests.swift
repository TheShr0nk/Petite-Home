import XCTest
import SwiftData
@testable import PetiteHome

@MainActor
final class MealsTests: XCTestCase {
    private var container: ModelContainer!
    override func setUp() async throws { container = PersistenceController.preview() }

    func testImporterReadsSchemaOrgRecipe() {
        let html = """
        <html><head><title>Best Chicken</title>
        <script type="application/ld+json">{"@context":"https://schema.org","@graph":[{"@type":"WebPage"},{"@type":"Recipe","name":"Sheet-pan chicken &amp; lemon","recipeIngredient":["4 chicken thighs","1 lemon","2 tbsp olive oil"],"recipeInstructions":[{"@type":"HowToStep","text":"Heat the oven to 425."},{"@type":"HowToStep","text":"Roast 35 minutes."}],"recipeYield":"4 servings","prepTime":"PT10M","cookTime":"PT35M","image":{"@type":"ImageObject","url":"https://x.test/a.jpg"}}]}</script>
        </head></html>
        """
        let d = RecipeImporter.parse(html: html)
        XCTAssertEqual(d.title, "Sheet-pan chicken & lemon")
        XCTAssertEqual(d.ingredients.count, 3)
        XCTAssertEqual(d.steps, ["Heat the oven to 425.", "Roast 35 minutes."])
        XCTAssertEqual(d.servings, 4)
        XCTAssertEqual(d.minutes, 45)
        XCTAssertEqual(d.imageURL, "https://x.test/a.jpg")
    }

    func testImporterFallsBackToTitle() {
        let d = RecipeImporter.parse(html: "<html><head><meta property=\"og:title\" content=\"Grandma&#39;s soup\"></head></html>")
        XCTAssertEqual(d.title, "Grandma's soup")
        XCTAssertTrue(d.ingredients.isEmpty)
    }

    func testISODurations() {
        XCTAssertEqual(RecipeImporter.minutes(fromISO8601: "PT1H30M"), 90)
        XCTAssertEqual(RecipeImporter.minutes(fromISO8601: "PT45M"), 45)
        XCTAssertNil(RecipeImporter.minutes(fromISO8601: "nope"))
    }

    func testShoppingListMergesAcrossRecipes() {
        let a = Recipe(title: "Tacos", ingredients: ["1 lb ground beef", "1 onion", "Tortillas"])
        let b = Recipe(title: "Soup", ingredients: ["2 onions, diced", "4 cups stock"])
        let today = Date()
        let m1 = PlannedMeal(date: today, slot: .dinner, recipe: a)
        let m2 = PlannedMeal(date: today.addingTimeInterval(86400), slot: .dinner, recipe: b)
        for x in [a, b] { container.mainContext.insert(x) }
        for x in [m1, m2] { container.mainContext.insert(x) }
        let lines = ShoppingList.lines(for: [m1, m2])
        XCTAssertEqual(lines.map(\.text), ["1 lb ground beef", "1 onion", "Tortillas", "4 cups stock"])
        XCTAssertEqual(lines.first { $0.key == "onion" }?.recipes, ["Tacos", "Soup"])
    }

    func testNormalizeStripsQuantitiesAndUnits() {
        XCTAssertEqual(ShoppingList.normalize("2 cups flour"), "flour")
        XCTAssertEqual(ShoppingList.normalize("½ tsp salt"), "salt")
        XCTAssertEqual(ShoppingList.normalize("3 large eggs, beaten"), "eggs")
    }

    func testMealsLandOnTheAgenda() {
        let r = Recipe(title: "Pasta")
        let m = PlannedMeal(date: Date(), slot: .dinner, recipe: r)
        container.mainContext.insert(r); container.mainContext.insert(m)
        let day = LifeSyncAgenda.build(events: [], tasks: [], meals: [m], from: Date(), days: 1)[0]
        XCTAssertEqual(day.items.first?.kind, .meal)
        XCTAssertEqual(day.items.first?.title, "Pasta")
    }

    func testShareTextIncludesEverything() {
        let r = Recipe(title: "Pasta", ingredients: ["Pasta", "Butter"], steps: ["Boil.", "Toss."])
        let t = RecipeShare.text(for: r)
        XCTAssertTrue(t.contains("· Pasta"))
        XCTAssertTrue(t.contains("2. Toss."))
        XCTAssertTrue(t.contains("petitehome.co"))
    }
}
