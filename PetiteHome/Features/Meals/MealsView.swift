import SwiftUI
import SwiftData

/// Meals: the week's plan (premium, synced with your partner) and the recipe
/// box with sharing (free). Lives as the middle segment of Life Sync.
struct MealsView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Bindable var household: Household
    @State private var showNewRecipe = false
    @State private var showShopping = false
    @State private var planning: Date?
    @State private var search = ""

    private var recipes: [Recipe] {
        let all = (household.recipes ?? []).sorted { ($0.isFavorite ? 0 : 1, $0.title) < ($1.isFavorite ? 0 : 1, $1.title) }
        guard !search.isEmpty else { return all }
        return all.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.tags.contains { $0.localizedCaseInsensitiveContains(search) } }
    }
    private var week: [Date] {
        let start = Calendar.current.startOfDay(for: Date())
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if entitlements.isPremium { weekPlan } else { lockedWeekPlan }
                BrandDivider()
                recipeBox
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .sheet(isPresented: $showNewRecipe) { RecipeEditorSheet(household: household, recipe: nil) }
        .sheet(isPresented: $showShopping) { ShoppingListSheet(household: household) }
        .sheet(item: Binding(get: { planning.map { DayBox(date: $0) } }, set: { planning = $0?.date })) { box in
            PlanMealSheet(household: household, date: box.date)
        }
        .navigationDestination(for: Recipe.self) { recipe in RecipeDetailView(recipe: recipe) }
    }

    // MARK: Week plan

    private var weekPlan: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "This week", detail: household.partner.map { "shared with \($0.displayName)" })
            Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        let meals = mealsOn(day)
                        Button { planning = day } label: {
                            HStack(spacing: Theme.Spacing.md) {
                                VStack(spacing: 0) {
                                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(Typography.capsLabel).textCase(.uppercase).foregroundStyle(Theme.Colors.sandDeep)
                                    Text(day.formatted(.dateTime.day())).font(Typography.serif(20)).foregroundStyle(Theme.Colors.ink)
                                }
                                .frame(width: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    if meals.isEmpty {
                                        Text("Decide dinner").font(Typography.body).foregroundStyle(Theme.Colors.powderBlueDk)
                                    } else {
                                        ForEach(meals) { m in
                                            HStack(spacing: Theme.Spacing.xs) {
                                                Text(m.displayTitle).font(Typography.body).foregroundStyle(Theme.Colors.ink).lineLimit(1)
                                                if m.slot != .dinner { Text("· \(m.slot.label.lowercased())").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) }
                                                if let cook = household.adults.first(where: { $0.id == m.cookAdultID }) { Text("· \(cook.displayName) cooks").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) }
                                            }
                                        }
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep)
                            }
                            .padding(.horizontal, Theme.Spacing.lg).padding(.vertical, Theme.Spacing.md)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if day != week.last { SandDivider().padding(.leading, Theme.Spacing.lg + 52) }
                    }
                }
            }
            Button { showShopping = true } label: { Label("Shopping list for the week", systemImage: "cart") }.buttonStyle(.outline)
        }
    }

    private var lockedWeekPlan: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(title: "This week")
            Text("Plan the week once, together. Whoever's cooking sees it, the shopping list writes itself, and dinner shows up on the Life Sync agenda.")
                .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
            LockedPreview(onTap: { appState.showPaywall(.mealPlan) }) {
                Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(zip(week.prefix(4), ["Sheet-pan chicken", "Leftovers", "Taco night", "Decide dinner"])), id: \.0) { day, title in
                            HStack(spacing: Theme.Spacing.md) {
                                VStack(spacing: 0) {
                                    Text(day.formatted(.dateTime.weekday(.abbreviated))).font(Typography.capsLabel).textCase(.uppercase).foregroundStyle(Theme.Colors.sandDeep)
                                    Text(day.formatted(.dateTime.day())).font(Typography.serif(20)).foregroundStyle(Theme.Colors.ink)
                                }
                                .frame(width: 40)
                                Text(title).font(Typography.body).foregroundStyle(title == "Decide dinner" ? Theme.Colors.powderBlueDk : Theme.Colors.ink)
                                Spacer()
                            }
                            .padding(.horizontal, Theme.Spacing.lg).padding(.vertical, Theme.Spacing.md)
                            SandDivider().padding(.leading, Theme.Spacing.lg + 52)
                        }
                    }
                }
            }
        }
    }

    private func mealsOn(_ day: Date) -> [PlannedMeal] {
        (household.meals ?? []).filter { Calendar.current.isDate($0.date, inSameDayAs: day) }.sorted { $0.slot.order < $1.slot.order }
    }

    // MARK: Recipe box

    private var recipeBox: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                SectionHeader(title: "Recipe box", detail: recipes.isEmpty ? nil : "\(recipes.count)")
                Button { showNewRecipe = true } label: { Image(systemName: "plus").font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.Colors.powderBlueDk).frame(width: 36, height: 36) }
                    .accessibilityLabel("Add a recipe")
            }
            if (household.recipes ?? []).count > 5 {
                TextField("Search recipes", text: $search)
                    .font(Typography.body).padding(.horizontal, 14).frame(minHeight: 44)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(Theme.Colors.white))
            }
            if recipes.isEmpty {
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Save the ones you actually make.").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                        Text("Paste a link from a blog, Instagram or TikTok and the app pulls the recipe in. Or type it. Then share it as a card with anyone.")
                            .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                        Button("Add the first recipe") { showNewRecipe = true }.buttonStyle(.primary)
                    }
                }
            } else {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe) { RecipeRow(recipe: recipe) }.buttonStyle(.plain)
                }
            }
        }
    }
}

struct DayBox: Identifiable { let date: Date; var id: Date { date } }

struct RecipeRow: View {
    let recipe: Recipe
    var body: some View {
        Card(padding: 0) {
            HStack(spacing: 0) {
                if let data = recipe.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: 72, height: 72).clipped()
                } else {
                    ZStack { Theme.Colors.creamTint; BrandIcon(systemName: "fork.knife", size: 22) }.frame(width: 72, height: 72)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(recipe.title).font(Typography.body).foregroundStyle(Theme.Colors.ink).lineLimit(1)
                        if recipe.isFavorite { Image(systemName: "heart.fill").font(.system(size: 11)).foregroundStyle(Theme.Colors.danger) }
                    }
                    Text([recipe.summary, recipe.timesCooked > 0 ? "made \(recipe.timesCooked)×" : ""].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                .padding(.horizontal, Theme.Spacing.md)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep).padding(.trailing, Theme.Spacing.lg)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }
}

// MARK: Recipe detail

struct RecipeDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var recipe: Recipe
    @State private var showEdit = false
    @State private var showPlan = false
    @State private var confirmDelete = false
    @State private var card: UIImage?
    @State private var cookedPop = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if let data = recipe.photo, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill().frame(height: 220).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Eyebrow(text: recipe.summary.isEmpty ? "Recipe" : recipe.summary)
                    Text(recipe.title).font(Typography.title).foregroundStyle(Theme.Colors.ink)
                    if !recipe.sourceURL.isEmpty, let url = URL(string: recipe.sourceURL) {
                        Link(url.host ?? "Source", destination: url).font(Typography.caption).foregroundStyle(Theme.Colors.powderBlueDk)
                    }
                }
                HStack(spacing: Theme.Spacing.sm) {
                    if let card {
                        ShareLink(item: RecipeCardFile(image: card, title: recipe.title),
                                  message: Text(RecipeShare.text(for: recipe)),
                                  preview: SharePreview(recipe.title, image: Image(uiImage: card))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.primary)
                        .simultaneousGesture(TapGesture().onEnded { Analytics.track(.recipeShared) })
                    } else {
                        Button { } label: { PulsingDots(color: Theme.Colors.white) }.buttonStyle(.primary).disabled(true)
                    }
                    Button {
                        if entitlements.isPremium { showPlan = true } else { appState.showPaywall(.mealPlan) }
                    } label: { Label("Plan it", systemImage: "calendar.badge.plus") }.buttonStyle(.outline)
                }
                Text("Share sends a recipe card and the full text. Works for Instagram, Messages, group chats, anywhere.")
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)

                SectionHeader(title: "Ingredients", detail: "\(recipe.ingredients.count)")
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { _, line in
                            HStack(alignment: .top, spacing: Theme.Spacing.sm) {
                                Circle().fill(Theme.Colors.sand).frame(width: 5, height: 5).padding(.top, 8)
                                Text(line).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                            }
                        }
                    }
                }
                if !recipe.steps.isEmpty {
                    SectionHeader(title: "Steps")
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { i, step in
                                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                                    Text("\(i + 1)").font(Typography.serif(20)).foregroundStyle(Theme.Colors.sandDeep).frame(width: 24, alignment: .trailing)
                                    Text(step).font(Typography.body).lineSpacing(3).foregroundStyle(Theme.Colors.ink)
                                }
                            }
                        }
                    }
                }
                if !recipe.notes.isEmpty {
                    SectionHeader(title: "Notes")
                    Text(recipe.notes).font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                }
                Button {
                    withAnimation(Motion.pop) { cookedPop = true }
                    recipe.timesCooked += 1; recipe.lastCookedAt = Date()
                    try? context.save()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { cookedPop = false }
                } label: {
                    Label(cookedPop ? "Nice. That's \(recipe.timesCooked)." : "We made it tonight", systemImage: cookedPop ? "checkmark.circle.fill" : "checkmark.circle")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.outline)
                .scaleEffect(cookedPop ? 1.02 : 1)
                Button("Remove recipe", role: .destructive) { confirmDelete = true }
                    .font(Typography.button).foregroundStyle(Theme.Colors.danger).frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.Spacing.gutter).padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle(recipe.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: Theme.Spacing.md) {
                    Button { withAnimation(Motion.pop) { recipe.isFavorite.toggle() }; try? context.save() } label: {
                        Image(systemName: recipe.isFavorite ? "heart.fill" : "heart").foregroundStyle(recipe.isFavorite ? Theme.Colors.danger : Theme.Colors.sandDeep)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    Button("Edit") { showEdit = true }.foregroundStyle(Theme.Colors.powderBlueDk)
                }
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: renderCard) { RecipeEditorSheet(household: recipe.household, recipe: recipe) }
        .sheet(isPresented: $showPlan) { PlanMealSheet(household: recipe.household, date: Date(), preselected: recipe) }
        .confirmationDialog("Remove this recipe?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) { context.delete(recipe); try? context.save(); dismiss() }
        }
        .task { renderCard() }
    }

    private func renderCard() {
        card = RecipeShare.card(for: recipe, householdName: recipe.household?.displayName.replacingOccurrences(of: "The ", with: "").replacingOccurrences(of: " family", with: "") ?? "Our")
    }
}
