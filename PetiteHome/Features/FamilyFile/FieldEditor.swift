import SwiftUI
import SwiftData

/// Routes a Family File field to the right editor sheet.
struct FieldEditor: View {
    @Bindable var household: Household
    @Bindable var file: FamilyFile
    let field: FamilyFileField

    var body: some View {
        NavigationStack {
            Group {
                switch field {
                case .emergencyContactFirst, .emergencyContactSecond:
                    EmergencyContactsEditor(contacts: $file.emergencyContacts)
                case .preferredHospital:
                    ContactEditor(title: field.label, contact: $file.preferredHospital, showRelationship: false, namePlaceholder: "Hospital")
                case .vetOrPetSitter:
                    ContactEditor(title: field.label, contact: $file.vetOrPetSitter, showRelationship: true, namePlaceholder: "Vet or sitter")
                case .homeAddress:
                    TextEditorSheet(title: field.label, text: $file.homeAddress, hint: "Street, city, state, ZIP", multiline: true)
                case .keysAndCodes:
                    KeysAndCodesEditor(file: file)
                case .healthInsurance:
                    InsuranceEditor(title: field.label, policy: Binding(get: { file.healthInsurance }, set: { file.healthInsurance = $0 ?? InsurancePolicy() }), household: household)
                case .dentalInsurance:
                    InsuranceEditor(title: field.label, policy: $file.dentalInsurance, household: household)
                case .homeownersOrRenters:
                    InsuranceEditor(title: field.label, policy: $file.homeownersOrRenters, household: household)
                case .autoInsurance:
                    InsuranceEditor(title: field.label, policy: $file.autoInsurance, household: household)
                case .pediatrician:
                    PediatriciansEditor(household: household)
                case .familyDoctor:
                    ContactEditor(title: field.label, contact: $file.familyDoctor, showRelationship: false, namePlaceholder: "Doctor or practice")
                case .pharmacy:
                    ContactEditor(title: field.label, contact: $file.pharmacy, showRelationship: false, namePlaceholder: "Pharmacy")
                case .designatedGuardian:
                    ContactEditor(title: field.label, contact: $file.designatedGuardian, showRelationship: true, namePlaceholder: "Full name",
                                  footnote: "This isn't legal paperwork. It's so the people around you know your wishes on the worst day.")
                        .onDisappear { if file.designatedGuardian?.isFilled == true { household.guardianUndecided = false } }
                case .backupGuardian:
                    ContactEditor(title: field.label, contact: $file.backupGuardian, showRelationship: true)
                case .whereTheWillIs:
                    TextEditorSheet(title: field.label, text: $file.whereTheWillIs, hint: "e.g. Fireproof box in the bedroom closet, copy with our attorney", multiline: true)
                case .attorney:
                    ContactEditor(title: field.label, contact: $file.attorney, showRelationship: false, namePlaceholder: "Attorney or firm")
                case .financialAdvisor:
                    ContactEditor(title: field.label, contact: $file.financialAdvisor, showRelationship: false, namePlaceholder: "Advisor or firm")
                case .lifeInsurance:
                    PolicyListEditor(title: field.label, policies: $file.lifeInsurance, household: household)
                case .instructionsForKids:
                    TextEditorSheet(title: field.label, text: $file.instructionsForKids, hint: "Bedtime, comfort items, what calms them down, what they're scared of. Write it like you're leaving it for a friend.", multiline: true)
                case .bankAccounts:
                    AccountListEditor(title: field.label, accounts: $file.bankAccounts)
                case .retirementAccounts:
                    AccountListEditor(title: field.label, accounts: $file.retirementAccounts)
                case .mortgageOrLandlord:
                    ContactEditor(title: field.label, contact: $file.mortgageOrLandlord, showRelationship: false, namePlaceholder: "Lender or landlord")
                case .utilities:
                    AccountListEditor(title: field.label, accounts: $file.utilities)
                case .recurringBills:
                    AccountListEditor(title: field.label, accounts: $file.recurringBills)
                case .passwordManager:
                    TextEditorSheet(title: field.label, text: $file.passwordManager, hint: "e.g. 1Password. The master password is in the safe.", multiline: true,
                                    footnote: "Say which one and where the master password is. Never the password itself.")
                case .vehicles:
                    VehicleListEditor(vehicles: $file.vehicles, household: household)
                }
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
    }
}

struct DoneToolbarItem: ToolbarContent {
    @Environment(\.dismiss) private var dismiss
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("Done") { dismiss() }.foregroundStyle(Theme.Colors.powderBlueDk)
        }
    }
}

/// Shared scroll-and-pad wrapper for editors.
struct EditorScroll<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) { content() }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.vertical, Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Contacts

struct ContactEditor: View {
    let title: String
    @Binding var contact: Contact?
    var showRelationship: Bool
    var namePlaceholder: String = "Full name"
    var footnote: String? = nil

    private var draft: Binding<Contact> { Binding(get: { contact ?? Contact() }, set: { contact = $0 }) }

    var body: some View {
        EditorScroll(title: title) {
            ContactEntry(contact: draft, showRelationship: showRelationship, namePlaceholder: namePlaceholder)
            LabeledField(label: "Email", text: draft.email, placeholder: "Email", keyboard: .emailAddress, contentType: .emailAddress, autocapitalization: .never)
            LabeledField(label: "Address", text: draft.address, placeholder: "Address", contentType: .fullStreetAddress)
            LabeledTextEditor(label: "Notes", text: draft.notes, hint: "Anything the person reading this should know")
            if let footnote {
                Text(footnote).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            }
            if contact?.isFilled == true {
                Button("Remove", role: .destructive) { contact = nil }
                    .font(Typography.button).foregroundStyle(Theme.Colors.danger).frame(maxWidth: .infinity)
            }
        }
    }
}

struct EmergencyContactsEditor: View {
    @Binding var contacts: [Contact]
    @State private var editingIndex: Int?

    var body: some View {
        List {
            Section {
                ForEach(Array(contacts.enumerated()), id: \.element.id) { index, contact in
                    Button { editingIndex = index } label: {
                        HStack {
                            Text("\(index + 1)").font(Typography.serif(18)).foregroundStyle(Theme.Colors.sandDeep).frame(width: 24)
                            VStack(alignment: .leading) {
                                Text(contact.name).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                Text([contact.relationship, contact.phone].filter { !$0.isEmpty }.joined(separator: " · ")).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                            }
                        }
                    }
                }
                .onMove { contacts.move(fromOffsets: $0, toOffset: $1) }
                .onDelete { contacts.remove(atOffsets: $0) }
                Button { contacts.append(Contact()); editingIndex = contacts.count - 1 } label: {
                    Label(contacts.isEmpty ? "Add the person who'd be called first" : "Add another person to call", systemImage: "plus")
                        .foregroundStyle(Theme.Colors.powderBlueDk)
                }
            } header: {
                Text("In the order they should be called")
            } footer: {
                Text("Drag to reorder. The first person is who gets the call.")
            }
            .listRowBackground(Theme.Colors.creamDeep)
        }
        .scrollContentBackground(.hidden)
        .toolbar { ToolbarItem(placement: .topBarLeading) { EditButton().foregroundStyle(Theme.Colors.sandDeep) } }
        .navigationTitle("Who to call")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(get: { editingIndex.map { IndexBox(value: $0) } }, set: { editingIndex = $0?.value })) { box in
            NavigationStack {
                ContactEditor(title: box.value == 0 ? "Call first" : "Call next",
                              contact: Binding(get: { contacts.indices.contains(box.value) ? contacts[box.value] : nil },
                                               set: { new in
                                                  guard contacts.indices.contains(box.value) else { return }
                                                  if let new { contacts[box.value] = new } else { contacts.remove(at: box.value) }
                                               }),
                              showRelationship: true)
                    .screenBackground()
                    .toolbar { DoneToolbarItem() }
            }
            .presentationBackground(Theme.Colors.cream)
        }
        .onDisappear { contacts.removeAll { !$0.isFilled } }
    }
}

struct IndexBox: Identifiable { let value: Int; var id: Int { value } }

struct PediatriciansEditor: View {
    @Bindable var household: Household
    var body: some View {
        EditorScroll(title: "Pediatrician") {
            if household.kids.isEmpty {
                Text("Add a child first, then their doctor.").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
            }
            ForEach(household.kids, id: \.uuid) { child in
                ChildDoctorRow(child: child, siblings: household.kids)
            }
        }
    }
}

private struct ChildDoctorRow: View {
    @Bindable var child: Child
    let siblings: [Child]
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack { AvatarView(initial: child.initial, kind: .child, size: 32); Text(child.displayName).font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.ink) }
            ContactEntry(contact: Binding(get: { child.pediatrician ?? Contact() }, set: { child.pediatrician = $0 }), showRelationship: false, namePlaceholder: "Doctor or practice")
            if siblings.count > 1, child.pediatrician?.isFilled == true {
                Button("Same doctor for everyone") { for s in siblings { s.pediatrician = child.pediatrician } }
                    .buttonStyle(.secondary)
            }
        }
        .padding(.bottom, Theme.Spacing.md)
    }
}

// MARK: Text

struct TextEditorSheet: View {
    let title: String
    @Binding var text: String
    var hint: String = ""
    var multiline: Bool = false
    var footnote: String? = nil
    var body: some View {
        EditorScroll(title: title) {
            if multiline {
                LabeledTextEditor(label: title, text: $text, hint: hint)
            } else {
                LabeledField(label: title, text: $text, placeholder: hint)
            }
            if let footnote { Text(footnote).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) }
        }
    }
}

struct KeysAndCodesEditor: View {
    @Bindable var file: FamilyFile
    @State private var gate = ""
    @State private var alarm = ""
    @State private var loaded = false

    var body: some View {
        EditorScroll(title: "Spare key, gate and alarm") {
            LabeledField(label: "Where the spare key is", text: $file.spareKeyLocation, placeholder: "e.g. With the neighbor at 12, or the lockbox by the side door")
            LabeledField(label: "Gate code", text: $gate, placeholder: "Gate code", keyboard: .numbersAndPunctuation, autocapitalization: .never)
            LabeledField(label: "Alarm code", text: $alarm, placeholder: "Alarm code", keyboard: .numbersAndPunctuation, autocapitalization: .never)
            Text("Codes are the one thing the app keeps that could open a door. They're encrypted and stored in your iCloud Keychain, not in the file.")
                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
        }
        .onAppear {
            guard !loaded else { return }
            gate = SecureCodes.read(.gateCode) ?? ""
            alarm = SecureCodes.read(.alarmCode) ?? ""
            loaded = true
        }
        .onDisappear {
            try? SecureCodes.save(gate, for: .gateCode)
            try? SecureCodes.save(alarm, for: .alarmCode)
            file.hasGateCode = !gate.isEmpty
            file.hasAlarmCode = !alarm.isEmpty
        }
    }
}

// MARK: Insurance

struct InsuranceEditor: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    let title: String
    @Binding var policy: InsurancePolicy?
    let household: Household
    @State private var hasRenewal = false

    private var binding: Binding<InsurancePolicy> { Binding(get: { policy ?? InsurancePolicy() }, set: { policy = $0 }) }

    var body: some View {
        EditorScroll(title: title) {
            InsuranceEntry(policy: binding, allowVaultSave: true) { image in
                VaultStore.save(image: image, title: "\(title) card", category: .insuranceCard, household: household, context: context)
            }
            LabeledTextEditor(label: "Notes", text: binding.notes, hint: "Deductible, who's covered, anything odd")
            RenewalRow(label: "Renews on", date: binding.expiresOn, remindersEnabled: binding.remindersEnabled, household: household)
            if policy?.isFilled == true {
                Button("Remove", role: .destructive) { policy = nil }
                    .font(Typography.button).foregroundStyle(Theme.Colors.danger).frame(maxWidth: .infinity)
            }
        }
    }
}

/// An optional date plus the premium "Remind me" toggle used by every expiring thing.
struct RenewalRow: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    let label: String
    @Binding var date: Date?
    @Binding var remindersEnabled: Bool
    let household: Household?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Toggle(isOn: Binding(get: { date != nil }, set: { on in date = on ? Calendar.current.date(byAdding: .year, value: 1, to: Date()) : nil })) {
                Text(label).font(Typography.body).foregroundStyle(Theme.Colors.ink)
            }
            .tint(Theme.Colors.powderBlueDk)
            if let current = date {
                DatePicker("Date", selection: Binding(get: { current }, set: { date = $0 }), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(Typography.body)
                    .tint(Theme.Colors.powderBlueDk)
                HStack {
                    Toggle(isOn: Binding(get: { entitlements.isPremium && remindersEnabled }, set: { on in
                        if entitlements.isPremium {
                            remindersEnabled = on
                            if on { Task { _ = await NotificationService.shared.requestPermission(); if let household { ExpirationScheduler.sync(household: household, isPremium: true) } } }
                        } else {
                            appState.showPaywall(.expirationReminder)
                        }
                    })) {
                        Text("Remind me").font(Typography.body).foregroundStyle(Theme.Colors.ink)
                    }
                    .tint(Theme.Colors.powderBlueDk)
                    if !entitlements.isPremium { PremiumPill() }
                }
                Text("Reminders 60, 30 and 7 days out.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            }
        }
        .padding(Theme.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(Theme.Colors.creamDeep))
    }
}

struct PolicyListEditor: View {
    let title: String
    @Binding var policies: [InsurancePolicy]
    let household: Household

    var body: some View {
        EditorScroll(title: title) {
            ForEach($policies) { $policy in
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        LabeledField(label: "Carrier", text: $policy.carrier, placeholder: "Carrier")
                        LabeledField(label: "Policy number", text: $policy.policyOrMemberID, placeholder: "Policy number", autocapitalization: .characters)
                        LabeledField(label: "Phone", text: $policy.phone, placeholder: "Phone", keyboard: .phonePad, autocapitalization: .never)
                        LabeledField(label: "Notes", text: $policy.notes, placeholder: "Who's covered, roughly how much, where the policy is")
                        Button("Remove", role: .destructive) { policies.removeAll { $0.id == policy.id } }.font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                    }
                }
            }
            Button { policies.append(InsurancePolicy()) } label: { Label(policies.isEmpty ? "Add a life insurance policy" : "Add another policy", systemImage: "plus") }.buttonStyle(.outline)
        }
        .onDisappear { policies.removeAll { !$0.isFilled } }
    }
}

// MARK: Accounts

struct AccountListEditor: View {
    let title: String
    @Binding var accounts: [AccountReference]

    var body: some View {
        EditorScroll(title: title) {
            Text("Institution, a nickname, who's on it, and the last 4. That's enough for someone to call and get help. Never the full number.")
                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            ForEach($accounts) { $account in
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        LabeledField(label: "Institution", text: $account.institution, placeholder: "e.g. Chase")
                        LabeledField(label: "Nickname", text: $account.nickname, placeholder: "e.g. Joint checking")
                        LabeledField(label: "Who's on it", text: $account.ownerNames, placeholder: "Names")
                        LabeledField(label: "Last 4", text: Binding(get: { account.lastFour }, set: { account.lastFour = String($0.filter(\.isNumber).suffix(4)) }), placeholder: "1234", keyboard: .numberPad)
                        LabeledField(label: "Notes", text: $account.notes, placeholder: "Autopay, what it's for")
                        Button("Remove", role: .destructive) { accounts.removeAll { $0.id == account.id } }.font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                    }
                }
            }
            Button { accounts.append(AccountReference()) } label: { Label(accounts.isEmpty ? "Add one" : "Add another", systemImage: "plus") }.buttonStyle(.outline)
        }
        .onDisappear { accounts.removeAll { !$0.isFilled } }
    }
}

struct VehicleListEditor: View {
    @Binding var vehicles: [Vehicle]
    let household: Household

    var body: some View {
        EditorScroll(title: "Vehicles") {
            ForEach($vehicles) { $vehicle in
                Card {
                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        LabeledField(label: "Year, make, model", text: $vehicle.yearMakeModel, placeholder: "e.g. 2021 Subaru Outback")
                        LabeledField(label: "Plate", text: $vehicle.plate, placeholder: "Plate", autocapitalization: .characters)
                        LabeledField(label: "Where the title is", text: $vehicle.titleLocation, placeholder: "e.g. Fireproof box")
                        LabeledField(label: "Loan servicer", text: $vehicle.loanServicer, placeholder: "If there's a loan")
                        RenewalRow(label: "Registration renews", date: $vehicle.registrationExpiresOn, remindersEnabled: $vehicle.remindersEnabled, household: household)
                        Button("Remove", role: .destructive) { vehicles.removeAll { $0.id == vehicle.id } }.font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                    }
                }
            }
            Button { vehicles.append(Vehicle()) } label: { Label(vehicles.isEmpty ? "Add a vehicle" : "Add another vehicle", systemImage: "plus") }.buttonStyle(.outline)
        }
        .onDisappear { vehicles.removeAll { !$0.isFilled } }
    }
}
