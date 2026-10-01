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
    @State private var confirmDelete = false
    @State private var confirmStopSharing = false
    @State private var confirmLeave = false
    @State private var dangerError: String?

    var body: some View {
        List {
            if !CloudIdentity.isICloudAvailable {
                Section {
                    Label("iCloud is off on this phone. Everything stays on this phone only, and sharing with a partner won't work until it's on.", systemImage: "icloud.slash")
                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                .listRowBackground(Theme.Colors.powderBlueMist)
            }
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
                    if isOwner {
                        Button("Stop sharing with my partner", role: .destructive) { confirmStopSharing = true }
                    }
                }
                if !isOwner, household.ownerUserID != nil {
                    Button("Leave this household", role: .destructive) { confirmLeave = true }
                }
                if let shareError { Text(shareError).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
            } header: { Text("Partner sharing") } footer: { Text("Your partner sees the same \(AppCopy.binder), and changes sync both ways. Free, always.") }
            .listRowBackground(Theme.Colors.creamDeep)

            Section {
                if entitlements.isPremium {
                    HStack { Text("Premium"); Spacer(); Text(premiumStatus).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) }
                    Button("Manage subscription") { showManageSubscription = true }
                } else {
                    Button("Go premium") { appState.showPaywall(.onboarding) }
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
                PhoneSyncToggles(household: household)
            } header: { Text("On this phone") } footer: {
                Text("Tasks land in a Petite Home list in Reminders, due at their hour. Plans, meals and expirations land in a Petite Home calendar. Check a task off in either place and the other follows. Each phone keeps its own copies.")
            }
            .listRowBackground(Theme.Colors.creamDeep)

            Section {
                Button("Delete this household and everything in it", role: .destructive) { confirmDelete = true }
                if let dangerError { Text(dangerError).font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
            } header: { Text("Your data") } footer: {
                Text("Deleting removes the \(AppCopy.binderLower), the vault, plans, meals and tasks from this phone and from iCloud. Export a PDF first if you want a copy. This can't be undone.")
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
                h.ownerUserID = household.ownerUserID
                try? context.save()
                appState.currentHouseholdID = h.uuid
                newHouseholdName = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("For a separated household, or a parent's file you're looking after.") }
        .confirmationDialog("Delete this household?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { deleteHousehold() }
        } message: { Text("Everything in it is removed from this phone and from iCloud. This can't be undone.") }
        .confirmationDialog("Stop sharing?", isPresented: $confirmStopSharing, titleVisibility: .visible) {
            Button("Stop sharing", role: .destructive) {
                Task {
                    do { try await CloudSharingService.shared.stopSharing(householdID: household.uuid) } catch { dangerError = error.localizedDescription }
                }
            }
        } message: { Text("Your partner loses access on their phone. Your data stays.") }
        .confirmationDialog("Leave this household?", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Leave", role: .destructive) {
                Task {
                    do {
                        try await CloudSharingService.shared.leave(householdID: household.uuid)
                        appState.currentHouseholdID = nil
                        appState.hasCompletedOnboarding = false
                        dismiss()
                    } catch { dangerError = error.localizedDescription }
                }
            }
        } message: { Text("It disappears from this phone. The owner keeps everything.") }
        .onDisappear { try? context.save() }
    }

    private var isOwner: Bool {
        household.ownerUserID == nil || household.ownerUserID == CloudIdentity.cachedUserID
    }

    /// Everything goes: models cascade from the household, reminders are cancelled, trusted links are
    /// revoked, and if this was the last household the app returns to onboarding.
    private func deleteHousehold() {
        for t in household.tasks ?? [] { NotificationService.shared.cancelTaskDue(id: t.uuid) }
        for p in household.plans ?? [] { NotificationService.shared.cancelTaskDue(id: p.uuid) }
        for exp in ExpirationScheduler.expirations(for: household) { NotificationService.shared.cancelExpiration(id: exp.id) }
        for trusted in household.trustedContacts ?? [] {
            if let name = trusted.shareRecordName { Task { await TrustedShareService.shared.revoke(recordName: name) } }
        }
        let id = household.uuid
        Task { try? await CloudSharingService.shared.stopSharing(householdID: id) }
        context.delete(household)
        try? context.save()
        let remaining = households.filter { $0.uuid != id }
        if let next = remaining.first {
            appState.currentHouseholdID = next.uuid
        } else {
            KeychainService.shared.remove(.gateCode, synchronizable: true)
            KeychainService.shared.remove(.alarmCode, synchronizable: true)
            appState.currentHouseholdID = nil
            appState.hasCompletedOnboarding = false
        }
        dismiss()
    }

    private var premiumStatus: String {
        if entitlements.hasActiveSubscription { return entitlements.isInTrial ? "Free trial" : "Active" }
        if let exp = entitlements.foundingUnlockExpiresAt, exp > Date() { return "Founding member until \(exp.formatted(date: .abbreviated, time: .omitted))" }
        if let exp = entitlements.localTrialExpiresAt, exp > Date() { return "Trial until \(exp.formatted(date: .abbreviated, time: .omitted))" }
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

/// The two per-phone switches for Reminders and Calendar export. Premium, like the Planner.
struct PhoneSyncToggles: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    let household: Household
    @State private var tasksOn = PhoneSyncService.shared.tasksToReminders
    @State private var calendarOn = PhoneSyncService.shared.plansToCalendar
    @State private var denied: String?

    var body: some View {
        Toggle(isOn: Binding(get: { tasksOn }, set: { on in set(tasks: on) })) {
            Label("Tasks in Reminders", systemImage: "checklist")
        }
        .tint(Theme.Colors.powderBlueDk)
        Toggle(isOn: Binding(get: { calendarOn }, set: { on in set(calendar: on) })) {
            Label("Plans and meals in Calendar", systemImage: "calendar.badge.plus")
        }
        .tint(Theme.Colors.powderBlueDk)
        if !entitlements.isPremium {
            HStack { Text("Part of the \(AppCopy.planner).").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep); Spacer(); PremiumPill() }
        }
        if let denied {
            Text(denied).font(Typography.caption).foregroundStyle(Theme.Colors.danger)
        }
    }

    private func set(tasks on: Bool) {
        guard entitlements.isPremium else { appState.showPaywall(.tasks); return }
        if !on { PhoneSyncService.shared.disableTasks(); tasksOn = false; return }
        Task {
            if await PhoneSyncService.shared.requestRemindersAccess() {
                PhoneSyncService.shared.tasksToReminders = true
                tasksOn = true
                PhoneSyncService.shared.syncIfEnabled(household: household, context: context, isPremium: true)
            } else {
                denied = "Reminders access is off. Turn it on in Settings → Privacy & Security → Reminders."
            }
        }
    }

    private func set(calendar on: Bool) {
        guard entitlements.isPremium else { appState.showPaywall(.lifeSync); return }
        if !on { PhoneSyncService.shared.disableCalendar(); calendarOn = false; return }
        Task {
            if await PhoneSyncService.shared.requestCalendarAccess() {
                PhoneSyncService.shared.plansToCalendar = true
                calendarOn = true
                PhoneSyncService.shared.syncIfEnabled(household: household, context: context, isPremium: true)
            } else {
                denied = "Calendar access is off. Turn it on in Settings → Privacy & Security → Calendars."
            }
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
