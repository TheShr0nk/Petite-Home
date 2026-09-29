import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Household.createdAt) private var households: [Household]
    @Bindable var household: Household

    @State private var foundingCode = ""
    @State private var foundingResult: String?
    @State private var sharePayload: SharePayload?
    @State private var shareError: String?
    @State private var showAddHousehold = false
    @State private var newHouseholdName = ""
    @State private var showManageSubscription = false

    var body: some View {
        List {
            Section("Household") {
                LabeledField(label: "Name", text: $household.name, placeholder: household.displayName).listRowBackground(Theme.Colors.creamDeep)
                ForEach(household.adults, id: \.uuid) { adult in
                    NavigationLink { AdultProfileView(adult: adult) } label: {
                        HStack { AvatarView(initial: adult.displayName, kind: .adult, size: 32); Text(adult.fullName.isEmpty ? adult.displayName : adult.fullName).font(Typography.body); Spacer(); if adult.isAccountOwner { Text("You").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) } }
                    }
                    .listRowBackground(Theme.Colors.creamDeep)
                }
                if household.adults.count < 2 {
                    Button { household.members?.append(Adult(firstName: "Partner", role: .parent)); try? context.save() } label: { Label("Add my partner", systemImage: "plus") }
                        .listRowBackground(Theme.Colors.creamDeep)
                } else {
                    Picker("This phone belongs to", selection: Binding(get: { appState.currentAdult(in: household)?.uuid ?? household.uuid }, set: { appState.currentAdultID = $0 })) {
                        ForEach(household.adults, id: \.uuid) { a in Text(a.displayName).tag(a.uuid) }
                    }
                    .listRowBackground(Theme.Colors.creamDeep)
                }
                if households.count > 1 {
                    Picker("Current household", selection: Binding(get: { appState.currentHouseholdID ?? household.uuid }, set: { appState.currentHouseholdID = $0 })) {
                        ForEach(households, id: \.uuid) { h in Text(h.displayName).tag(h.uuid) }
                    }
                    .listRowBackground(Theme.Colors.creamDeep)
                }
                Button {
                    if entitlements.isPremium { showAddHousehold = true } else { appState.showPaywall(.multipleHouseholds) }
                } label: {
                    HStack { Label("Add another household", systemImage: "plus.square.on.square"); Spacer(); if !entitlements.isPremium { PremiumPill() } }
                }
                .listRowBackground(Theme.Colors.creamDeep)
            }

            Section {
                let partners = CloudSharingService.shared.participants(householdID: household.uuid)
                if partners.isEmpty {
                    Button { invitePartner() } label: { Label(household.partner.map { "Invite \($0.displayName)" } ?? "Invite my partner", systemImage: "person.2") }
                } else {
                    ForEach(partners, id: \.userIdentity.userRecordID?.recordName) { p in
                        HStack {
                            Text(p.userIdentity.nameComponents?.formatted() ?? p.userIdentity.lookupInfo?.emailAddress ?? "Partner").font(Typography.body)
                            Spacer()
                            Text(p.acceptanceStatus == .accepted ? "Sharing" : "Invited").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        }
                    }
                    Button("Manage sharing") { invitePartner() }
                }
                if let shareError { Text(shareError).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
            } header: { Text("Partner sharing") } footer: { Text("Your partner sees the same \(AppCopy.binder), and changes sync both ways. Free, always.") }
            .listRowBackground(Theme.Colors.creamDeep)

            Section {
                if entitlements.isPremium {
                    HStack { Text("Premium"); Spacer(); Text(premiumStatus).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) }
                    Button("Manage subscription") { showManageSubscription = true }
                } else {
                    Button("Start free trial") { appState.showPaywall(.onboarding) }
                    Button("Restore purchases") { Task { await entitlements.restore() } }
                }
            } header: { Text("Premium") } footer: { Text("Reminders, the vault, household tasks and trusted-person sharing.") }
            .listRowBackground(Theme.Colors.creamDeep)

            Section {
                LabeledField(label: "Reservation code", text: $foundingCode, placeholder: "PH-XXXX-XXXX", autocapitalization: .characters)
                Button("Redeem") {
                    foundingResult = entitlements.redeemFoundingCode(foundingCode) ? "Premium is on for 12 months. Thank you for being early." : "That code didn't match. Check the letters and try again."
                }
                .disabled(foundingCode.isEmpty)
                if let foundingResult { Text(foundingResult).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) }
            } header: { Text("Founding 500") } footer: { Text("Reserved a bag from the first 500? Your code unlocks premium for a year.") }
            .listRowBackground(Theme.Colors.creamDeep)

            Section("Notifications") {
                NotificationSettingsRow()
            }
            .listRowBackground(Theme.Colors.creamDeep)

            Section {
                NavigationLink { PicksView() } label: { Label("Petite Picks", systemImage: "sparkles") }
                Link("Privacy", destination: URL(string: "https://petitehome.co/privacy")!)
                Link("Terms", destination: URL(string: "https://petitehome.co/terms")!)
                Link("Email us", destination: URL(string: "mailto:ryan@petitehome.co")!)
            } header: { Text("Petite Home Co.") } footer: {
                Text("Less to question. More to trust.\nVersion \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
            }
            .listRowBackground(Theme.Colors.creamDeep)
        }
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { DoneToolbarItem() }
        .sheet(item: $sharePayload) { p in CloudSharingSheet(share: p.share, container: p.container) }
        .manageSubscriptionsSheet(isPresented: $showManageSubscription)
        .alert("New household", isPresented: $showAddHousehold) {
            TextField("Name", text: $newHouseholdName)
            Button("Add") {
                let h = Household(name: newHouseholdName)
                context.insert(h)
                h.familyFile = FamilyFile()
                h.members = [Adult(firstName: household.owner?.firstName ?? "Me", lastName: household.owner?.lastName ?? "", role: .parent, isAccountOwner: true)]
                h.ownerAppleUserID = household.ownerAppleUserID
                try? context.save()
                appState.currentHouseholdID = h.uuid
                newHouseholdName = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("For a separated household, or a parent's file you're looking after.") }
        .onDisappear { try? context.save() }
    }

    private var premiumStatus: String {
        if entitlements.hasActiveSubscription { return entitlements.isInTrial ? "Free trial" : "Active" }
        if let exp = entitlements.foundingUnlockExpiresAt { return "Founding member until \(exp.formatted(date: .abbreviated, time: .omitted))" }
        return "Active"
    }

    private func invitePartner() {
        Task {
            do {
                let (share, container) = try await CloudSharingService.shared.share(for: household.uuid, title: "Our \(AppCopy.binder)")
                sharePayload = SharePayload(share: share, container: container)
            } catch { shareError = error.localizedDescription }
        }
    }
}

struct NotificationSettingsRow: View {
    @State private var status: UNAuthorizationStatus = .notDetermined
    var body: some View {
        HStack {
            Text("Reminders")
            Spacer()
            switch status {
            case .authorized, .provisional, .ephemeral: Text("On").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
            case .denied: Button("Turn on in Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) } }.font(Typography.caption)
            default: Button("Turn on") { Task { _ = await NotificationService.shared.requestPermission(); status = await NotificationService.shared.authorizationStatus() } }.font(Typography.caption)
            }
        }
        .task { status = await NotificationService.shared.authorizationStatus() }
    }
}

/// An adult's details, including dated items like a passport or licence.
struct AdultProfileView: View {
    @Environment(\.modelContext) private var context
    @Environment(EntitlementStore.self) private var entitlements
    @Bindable var adult: Adult
    var body: some View {
        EditorScroll(title: adult.displayName) {
            LabeledField(label: "First name", text: $adult.firstName, placeholder: "First name", contentType: .givenName)
            LabeledField(label: "Last name", text: $adult.lastName, placeholder: "Last name", contentType: .familyName)
            LabeledField(label: "Phone", text: $adult.phone, placeholder: "Phone", keyboard: .phonePad, contentType: .telephoneNumber, autocapitalization: .never)
            LabeledField(label: "Email", text: $adult.email, placeholder: "Email", keyboard: .emailAddress, contentType: .emailAddress, autocapitalization: .never)
            LabeledField(label: "Employer", text: $adult.employer, placeholder: "Employer", contentType: .organizationName)
            LabeledField(label: "Work phone", text: $adult.workPhone, placeholder: "Work phone", keyboard: .phonePad, autocapitalization: .never)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Role").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                HStack { ForEach(AdultRole.allCases, id: \.rawValue) { r in Chip(label: r.label, isSelected: adult.role == r) { adult.role = r } } }
            }
            SectionHeader(title: "Dates that expire")
            ExpiringItemsEditor(items: $adult.expiringItems, suggestions: ["Passport", "Driver's license"], household: adult.household)
        }
        .screenBackground()
        .onDisappear {
            try? context.save()
            if let h = adult.household { ExpirationScheduler.sync(household: h, isPremium: entitlements.isPremium) }
        }
    }
}
