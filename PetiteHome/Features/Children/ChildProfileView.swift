import SwiftUI
import SwiftData

struct AddChildView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let household: Household
    @State private var firstName = ""
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()

    var body: some View {
        EditorScroll(title: "Add a child") {
            LabeledField(label: "First name", text: $firstName, placeholder: "First name", contentType: .givenName)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Birthdate").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                DatePicker("Birthdate", selection: $dateOfBirth, in: ...Calendar.current.date(byAdding: .month, value: 10, to: Date())!, displayedComponents: .date)
                    .datePickerStyle(.wheel).labelsHidden().frame(maxHeight: 150)
            }
            Button("Add \(firstName.isEmpty ? "child" : firstName)") {
                let child = Child(firstName: firstName, dateOfBirth: dateOfBirth)
                household.children?.append(child)
                household.youngestChildSegment = AgeSegment.forYoungest(birthdates: household.kids.map(\.dateOfBirth), expecting: household.isExpecting)
                try? context.save()
                dismiss()
            }
            .buttonStyle(.primary(enabled: !firstName.isEmpty)).disabled(firstName.isEmpty)
        }
        .screenBackground()
    }
}

/// A child's profile: doctor, allergies, meds, sizes (with premium history), school, notes, expiring dates.
struct ChildProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var child: Child
    @State private var editingDoctor = false
    @State private var editingSchool = false
    @State private var editingSizes = false
    @State private var showHistory = false
    @State private var newAllergy = ""
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                HStack(spacing: Theme.Spacing.lg) {
                    AvatarView(initial: child.initial, kind: .child, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(child.displayName).font(Typography.title).foregroundStyle(Theme.Colors.ink)
                        Text("\(child.ageShort) · born \(child.dateOfBirth.formatted(date: .long, time: .omitted))").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    }
                }

                Card {
                    VStack(spacing: 0) {
                        FieldRow(label: "Doctor", value: child.pediatrician?.summary, instruction: "Add \(child.displayName)'s doctor") { editingDoctor = true }
                        SandDivider()
                        FieldRow(label: "School or daycare", value: child.school?.summary, instruction: "Add where they go during the day") { editingSchool = true }
                        SandDivider()
                        FieldRow(label: "Blood type", value: child.bloodType, instruction: "Add blood type if you know it") { }
                            .overlay(alignment: .trailing) {
                                Picker("Blood type", selection: Binding(get: { child.bloodType ?? "" }, set: { child.bloodType = $0.isEmpty ? nil : $0 })) {
                                    Text("Unknown").tag("")
                                    ForEach(["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"], id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu).tint(Theme.Colors.sandDeep).labelsHidden()
                            }
                    }
                }

                SectionHeader(title: "Sizes", detail: "updated \(child.sizeUpdatedAt.formatted(.relative(presentation: .named)))")
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        HStack(spacing: Theme.Spacing.xl) {
                            sizeCell("Clothing", child.clothingSize)
                            sizeCell("Shoes", child.shoeSize)
                            sizeCell("Diapers", child.diaperSize)
                        }
                        if let nudge = sizeNudge {
                            Text(nudge).font(Typography.caption).foregroundStyle(Theme.Colors.warn)
                        }
                        HStack {
                            Button("Update sizes") { editingSizes = true }.font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.powderBlueDk)
                            Spacer()
                            Button {
                                if entitlements.isPremium { showHistory = true } else { appState.showPaywall(.sizeHistory) }
                            } label: {
                                HStack(spacing: Theme.Spacing.sm) { Text("History").font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.powderBlueDk); if !entitlements.isPremium { PremiumPill() } }
                            }
                        }
                    }
                }

                SectionHeader(title: "Allergies")
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        if child.allergies.isEmpty {
                            Text("Add anything a caregiver must know about").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                        }
                        FlowLayout(spacing: Theme.Spacing.sm) {
                            ForEach(child.allergies, id: \.self) { allergy in
                                Chip(label: allergy, systemImage: "xmark", isSelected: true) { child.allergies.removeAll { $0 == allergy } }
                            }
                        }
                        HStack {
                            TextField("e.g. Peanuts", text: $newAllergy)
                                .font(Typography.body).padding(.horizontal, 14).frame(minHeight: 44)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(Theme.Colors.white))
                                .onSubmit(addAllergy)
                            Button("Add", action: addAllergy).font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.powderBlueDk).disabled(newAllergy.isEmpty)
                        }
                    }
                }

                SectionHeader(title: "Medications")
                MedicationsEditor(medications: $child.medications)

                SectionHeader(title: "Dates that expire")
                ExpiringItemsEditor(items: $child.expiringItems, suggestions: ["Passport", "Car seat"], household: child.household)

                SectionHeader(title: "Notes")
                LabeledTextEditor(label: "For whoever's looking after \(child.displayName)", text: $child.notes, hint: "Bedtime, comfort items, what calms them down")

                Button("Remove \(child.displayName)", role: .destructive) { confirmDelete = true }
                    .font(Typography.button).foregroundStyle(Theme.Colors.danger).frame(maxWidth: .infinity).padding(.top)
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationTitle(child.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingDoctor, onDismiss: save) {
            NavigationStack { ContactEditor(title: "\(child.displayName)'s doctor", contact: $child.pediatrician, showRelationship: false, namePlaceholder: "Doctor or practice").screenBackground().toolbar { DoneToolbarItem() } }
                .presentationBackground(Theme.Colors.cream)
        }
        .sheet(isPresented: $editingSchool, onDismiss: save) {
            NavigationStack { ContactEditor(title: "School or daycare", contact: $child.school, showRelationship: false, namePlaceholder: "School").screenBackground().toolbar { DoneToolbarItem() } }
                .presentationBackground(Theme.Colors.cream)
        }
        .sheet(isPresented: $editingSizes, onDismiss: save) {
            SizeEditorSheet(child: child).presentationDetents([.medium]).presentationBackground(Theme.Colors.cream)
        }
        .sheet(isPresented: $showHistory) {
            SizeHistorySheet(child: child).presentationBackground(Theme.Colors.cream)
        }
        .confirmationDialog("Remove \(child.displayName) from the household?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                context.delete(child)
                try? context.save()
                dismiss()
            }
        }
        .onDisappear(perform: save)
    }

    private func sizeCell(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            Text(value?.isEmpty == false ? value! : "—").font(Typography.serif(22)).foregroundStyle(Theme.Colors.ink)
        }
    }

    /// Premium: "last changed 4 months ago — probably time to check".
    private var sizeNudge: String? {
        guard entitlements.isPremium else { return nil }
        let months = Calendar.current.dateComponents([.month], from: child.sizeUpdatedAt, to: Date()).month ?? 0
        guard months >= 4 else { return nil }
        return "Last changed \(months) months ago. Probably time to check."
    }

    private func addAllergy() {
        let trimmed = newAllergy.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        child.allergies.append(trimmed)
        newAllergy = ""
    }

    private func save() {
        try? context.save()
        if let household = child.household { ExpirationScheduler.sync(household: household, isPremium: entitlements.isPremium) }
    }
}

struct SizeEditorSheet: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss
    @Bindable var child: Child
    @State private var clothing = ""
    @State private var shoe = ""
    @State private var diaper = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("Sizes right now").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
            LabeledField(label: "Clothing", text: $clothing, placeholder: "e.g. 2T")
            LabeledField(label: "Shoes", text: $shoe, placeholder: "e.g. 6")
            LabeledField(label: "Diapers", text: $diaper, placeholder: "e.g. 4, or none")
            Spacer()
            Button("Save") {
                child.updateSizes(clothing: clothing, shoe: shoe, diaper: diaper, keepHistory: entitlements.isPremium)
                dismiss()
            }.buttonStyle(.primary)
        }
        .padding(Theme.Spacing.gutter)
        .screenBackground()
        .onAppear { clothing = child.clothingSize ?? ""; shoe = child.shoeSize ?? ""; diaper = child.diaperSize ?? "" }
    }
}

struct SizeHistorySheet: View {
    let child: Child
    var body: some View {
        NavigationStack {
            List {
                if child.sizeHistory.isEmpty {
                    Text("Update sizes once and the history starts here.").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                        .listRowBackground(Theme.Colors.creamDeep)
                }
                ForEach(child.sizeHistory.sorted { $0.recordedAt > $1.recordedAt }) { record in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.recordedAt.formatted(date: .abbreviated, time: .omitted)).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        Text([("Clothing", record.clothing), ("Shoes", record.shoe), ("Diapers", record.diaper)].filter { !$0.1.isEmpty }.map { "\($0.0) \($0.1)" }.joined(separator: " · "))
                            .font(Typography.body).foregroundStyle(Theme.Colors.ink)
                    }
                    .listRowBackground(Theme.Colors.creamDeep)
                }
            }
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle("\(child.displayName)'s sizes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { DoneToolbarItem() }
        }
    }
}

struct MedicationsEditor: View {
    @Binding var medications: [Medication]
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach($medications) { $med in
                Card {
                    VStack(spacing: Theme.Spacing.sm) {
                        LabeledField(label: "Medication", text: $med.name, placeholder: "Name")
                        HStack {
                            LabeledField(label: "Dose", text: $med.dose, placeholder: "e.g. 5 ml")
                            LabeledField(label: "When", text: $med.schedule, placeholder: "e.g. Bedtime")
                        }
                        Button("Remove", role: .destructive) { medications.removeAll { $0.id == med.id } }.font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                    }
                }
            }
            Button { medications.append(Medication()) } label: { Label(medications.isEmpty ? "Add a medication" : "Add another", systemImage: "plus") }.buttonStyle(.outline)
        }
    }
}

/// Dated items on a person: passport, licence, car seat. Each has the premium "Remind me".
struct ExpiringItemsEditor: View {
    @Binding var items: [ExpiringItem]
    let suggestions: [String]
    let household: Household?

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach($items) { $item in
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        LabeledField(label: "What", text: $item.title, placeholder: "e.g. Passport")
                        RenewalRow(label: "Expires", date: Binding(get: { item.expiresOn }, set: { item.expiresOn = $0 ?? item.expiresOn }), remindersEnabled: $item.remindersEnabled, household: household)
                        Button("Remove", role: .destructive) { items.removeAll { $0.id == item.id } }.font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                    }
                }
            }
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(suggestions, id: \.self) { s in
                    Chip(label: "Add \(s.lowercased())", systemImage: "plus") {
                        items.append(ExpiringItem(title: s, expiresOn: Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()))
                    }
                }
            }
        }
    }
}
