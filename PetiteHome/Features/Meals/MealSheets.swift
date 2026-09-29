import SwiftUI
import SwiftData
import PhotosUI

/// Add or edit a recipe: paste a link to import, or type it in.
struct RecipeEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let household: Household?
    let recipe: Recipe?

    @State private var link = ""
    @State private var importing = false
    @State private var importError: String?
    @State private var title = ""
    @State private var ingredientsText = ""
    @State private var stepsText = ""
    @State private var servings = 4
    @State private var minutes = 30
    @State private var notes = ""
    @State private var tagsText = ""
    @State private var sourceURL = ""
    @State private var photo: Data?
    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            EditorScroll(title: recipe == nil ? "Add a recipe" : "Edit recipe") {
                if recipe == nil {
                    Card(background: Theme.Colors.powderBlueMist) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Paste a link").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                            Text("From a blog, a caption, or a recipe someone sent you. The app reads the recipe off the page.")
                                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                            HStack(spacing: Theme.Spacing.sm) {
                                TextField("https://", text: $link)
                                    .font(Typography.body).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .padding(.horizontal, 14).frame(minHeight: 44)
                                    .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(Theme.Colors.white))
                                    .onSubmit { Task { await importLink() } }
                                Button(importing ? "…" : "Import") { Task { await importLink() } }
                                    .font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.powderBlueDk).disabled(link.isEmpty || importing)
                            }
                            if importing { PulsingDots() }
                            if let importError { Text(importError).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
                        }
                    }
                }
                LabeledField(label: "Name", text: $title, placeholder: "e.g. Sheet-pan chicken", autocapitalization: .sentences)
                HStack(spacing: Theme.Spacing.lg) {
                    Stepper("Serves \(servings)", value: $servings, in: 1...24).font(Typography.body)
                    Stepper("\(minutes) min", value: $minutes, in: 5...600, step: 5).font(Typography.body)
                }
                LabeledTextEditor(label: "Ingredients, one per line", text: $ingredientsText, hint: "2 chicken thighs\n1 lemon\nolive oil")
                LabeledTextEditor(label: "Steps, one per line", text: $stepsText, hint: "Heat the oven to 425.\nToss everything on the pan.")
                LabeledField(label: "Tags", text: $tagsText, placeholder: "weeknight, kids like it", autocapitalization: .never)
                LabeledTextEditor(label: "Notes", text: $notes, hint: "Theo eats this without the sauce.")
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    HStack {
                        if let photo, let image = UIImage(data: photo) {
                            Image(uiImage: image).resizable().scaledToFill().frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("Change photo")
                        } else {
                            Label("Add a photo", systemImage: "photo")
                        }
                    }
                }
                .buttonStyle(.outline)
                .onChange(of: pickedItem) { _, item in
                    Task { if let data = try? await item?.loadTransferable(type: Data.self), let img = UIImage(data: data) { photo = img.jpegData(compressionQuality: 0.8) } }
                }
                Button("Save") { save() }.buttonStyle(.primary(enabled: !title.isEmpty)).disabled(title.isEmpty)
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
        .onAppear {
            guard let recipe else { return }
            title = recipe.title; ingredientsText = recipe.ingredients.joined(separator: "\n"); stepsText = recipe.steps.joined(separator: "\n")
            servings = recipe.servings; minutes = recipe.minutes; notes = recipe.notes; tagsText = recipe.tags.joined(separator: ", ")
            sourceURL = recipe.sourceURL; photo = recipe.photo
        }
    }

    private func importLink() async {
        importing = true; importError = nil
        defer { importing = false }
        do {
            let draft = try await RecipeImporter.fetch(link)
            title = draft.title
            ingredientsText = draft.ingredients.joined(separator: "\n")
            stepsText = draft.steps.joined(separator: "\n")
            servings = max(draft.servings, 1); minutes = max(draft.minutes, 5); sourceURL = draft.sourceURL
            if let image = draft.imageURL, let url = URL(string: image), let (data, _) = try? await URLSession.shared.data(from: url), let img = UIImage(data: data) {
                photo = img.jpegData(compressionQuality: 0.8)
            }
            Analytics.track(.recipeImported, ["host": URL(string: draft.sourceURL)?.host ?? "unknown"])
        } catch {
            importError = error.localizedDescription
        }
    }

    private func save() {
        let target = recipe ?? Recipe(title: title)
        target.title = title
        target.ingredients = ingredientsText.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        target.steps = stepsText.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        target.servings = servings; target.minutes = minutes; target.notes = notes
        target.tags = tagsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        target.sourceURL = sourceURL; target.photo = photo
        if recipe == nil {
            target.createdByAdultID = household.flatMap { appState.currentAdult(in: $0)?.uuid }
            household?.recipes?.append(target)
        }
        try? context.save()
        dismiss()
    }
}

/// Put something on a day: a recipe from the box or a freeform title, and who's cooking.
struct PlanMealSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let household: Household?
    @State var date: Date
    var preselected: Recipe? = nil

    @State private var slot: MealSlot = .dinner
    @State private var recipe: Recipe?
    @State private var freeform = ""
    @State private var cookID: UUID?

    private var existing: [PlannedMeal] {
        (household?.meals ?? []).filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.sorted { $0.slot.order < $1.slot.order }
    }

    var body: some View {
        NavigationStack {
            EditorScroll(title: date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
                if preselected != nil {
                    DatePicker("Day", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date).font(Typography.body).tint(Theme.Colors.powderBlueDk)
                }
                if !existing.isEmpty {
                    SectionHeader(title: "Already planned")
                    ForEach(existing) { meal in
                        Card {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(meal.displayTitle).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                    Text(meal.slot.label + (household?.adults.first { $0.uuid == meal.cookAdultID }.map { " · \($0.displayName) cooks" } ?? "")).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                                }
                                Spacer()
                                Button("Remove") { context.delete(meal); try? context.save() }.font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Which meal").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    HStack { ForEach(MealSlot.allCases) { s in Chip(label: s.label, isSelected: slot == s) { slot = s } } }
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("What").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    let box = (household?.recipes ?? []).sorted { ($0.isFavorite ? 0 : 1, $0.title) < ($1.isFavorite ? 0 : 1, $1.title) }
                    if box.isEmpty {
                        Text("No recipes in the box yet. Type what's for dinner below, or add recipes from the Meals tab.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    }
                    ForEach(box.prefix(8)) { r in
                        SelectableRow(title: r.title, detail: r.summary, isSelected: recipe?.uuid == r.uuid) { recipe = recipe?.uuid == r.uuid ? nil : r; if recipe != nil { freeform = "" } }
                    }
                    LabeledField(label: "Or just say it", text: $freeform, placeholder: "Leftovers, takeout, pasta", autocapitalization: .sentences)
                        .onChange(of: freeform) { _, v in if !v.isEmpty { recipe = nil } }
                }
                if let household, household.adults.count > 1 {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("Who's cooking").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                        HStack {
                            Chip(label: "Either of us", isSelected: cookID == nil) { cookID = nil }
                            ForEach(household.adults) { a in Chip(label: a.displayName, isSelected: cookID == a.uuid) { cookID = a.uuid } }
                        }
                    }
                }
                Button("Add to the week") { save() }.buttonStyle(.primary(enabled: recipe != nil || !freeform.isEmpty)).disabled(recipe == nil && freeform.isEmpty)
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
        .onAppear { recipe = preselected }
    }

    private func save() {
        let meal = PlannedMeal(date: date, slot: slot, title: freeform, recipe: recipe)
        meal.cookAdultID = cookID
        household?.meals?.append(meal)
        try? context.save()
        Analytics.track(.mealPlanned, ["slot": slot.rawValue, "fromRecipe": recipe != nil])
        dismiss()
    }
}

/// Everything the week's recipes need, checkable, shared with the partner.
struct ShoppingListSheet: View {
    @Environment(\.modelContext) private var context
    @Bindable var household: Household

    private var lines: [ShoppingList.Line] {
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        return ShoppingList.lines(for: (household.meals ?? []).filter { $0.date >= start && $0.date < end })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    if lines.isEmpty {
                        Text("Plan a recipe for this week and its ingredients land here.").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                    } else {
                        Text("\(lines.filter { !household.groceryChecked.contains($0.key) }.count) left to get").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        Card(padding: 0) {
                            VStack(spacing: 0) {
                                ForEach(lines) { line in
                                    let done = household.groceryChecked.contains(line.key)
                                    Button {
                                        withAnimation(Motion.pop) {
                                            if done { household.groceryChecked.removeAll { $0 == line.key } } else { household.groceryChecked.append(line.key) }
                                        }
                                        try? context.save()
                                    } label: {
                                        HStack(spacing: Theme.Spacing.md) {
                                            Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.system(size: 22, weight: .light))
                                                .foregroundStyle(done ? Theme.Colors.success : Theme.Colors.sand).contentTransition(.symbolEffect(.replace))
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(line.text).font(Typography.body).foregroundStyle(Theme.Colors.ink).strikethrough(done, color: Theme.Colors.sandDeep)
                                                Text(line.recipes.joined(separator: ", ")).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                                            }
                                            Spacer()
                                        }
                                        .padding(.horizontal, Theme.Spacing.lg).padding(.vertical, Theme.Spacing.md).contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    if line.id != lines.last?.id { SandDivider().padding(.leading, Theme.Spacing.lg + 34) }
                                }
                            }
                        }
                        ShareLink(item: lines.map { (household.groceryChecked.contains($0.key) ? "✓ " : "· ") + $0.text }.joined(separator: "\n")) {
                            Label("Send the list", systemImage: "square.and.arrow.up")
                        }.buttonStyle(.outline)
                        Button("Clear checks") { household.groceryChecked = []; try? context.save() }.buttonStyle(.secondary)
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter).padding(.vertical, Theme.Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("Shopping list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
    }
}
