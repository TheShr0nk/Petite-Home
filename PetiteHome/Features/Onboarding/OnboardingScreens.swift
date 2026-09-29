import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: Screen 1 — Hook

struct HookScreen: View {
    let onContinue: () -> Void
    @State private var showButton = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: 60)
            RevealLines(lines: [
                "If something happened to you tonight,",
                "would anyone know where to find your kids' insurance,",
                "their doctor,",
                "or who's supposed to take them?",
            ]) {
                withAnimation(.easeIn(duration: 1.0)) { showButton = true }
            }
            Spacer()
            Button("Let's fix that", action: onContinue)
                .buttonStyle(.primary)
                .opacity(showButton ? 1 : 0)
                .disabled(!showButton)
        }
        .padding(.horizontal, Theme.Spacing.gutter)
        .padding(.bottom, Theme.Spacing.lg)
    }
}

// MARK: Screen 2 — Who's in your household

struct HouseholdScreen: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void
    @State private var editingChild: OnboardingDraft.ChildDraft?

    var body: some View {
        OnboardingScreen(eyebrow: "Your household", hook: "Who's in your household?") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                FlowLayout(spacing: Theme.Spacing.sm) {
                    Chip(label: "Me", systemImage: "checkmark", isSelected: true) { }
                    Chip(label: draft.includesPartner && !draft.partnerFirstName.isEmpty ? draft.partnerFirstName : "My partner",
                         systemImage: draft.includesPartner ? "checkmark" : "plus",
                         isSelected: draft.includesPartner) {
                        draft.includesPartner.toggle()
                    }
                    Chip(label: "Expecting", systemImage: draft.isExpecting ? "checkmark" : "plus", isSelected: draft.isExpecting) {
                        draft.isExpecting.toggle()
                    }
                    ForEach(draft.children) { child in
                        Chip(label: child.firstName.isEmpty ? "Child" : "\(child.firstName), \(child.ageShort)",
                             systemImage: "pencil", isSelected: true) {
                            editingChild = child
                        }
                    }
                    Chip(label: "Add a child", systemImage: "plus") {
                        let new = OnboardingDraft.ChildDraft()
                        draft.children.append(new)
                        editingChild = new
                    }
                }
                if draft.includesPartner {
                    LabeledField(label: "Partner's first name", text: $draft.partnerFirstName, placeholder: "First name", contentType: .givenName)
                }
            }
        } actions: {
            Button("Continue", action: onContinue).buttonStyle(.primary)
        }
        .sheet(item: $editingChild) { child in
            ChildDraftSheet(child: binding(for: child)) {
                draft.children.removeAll { $0.id == child.id }
            }
            .presentationDetents([.medium])
            .presentationBackground(Theme.Colors.cream)
        }
    }

    private func binding(for child: OnboardingDraft.ChildDraft) -> Binding<OnboardingDraft.ChildDraft> {
        Binding(
            get: { draft.children.first { $0.id == child.id } ?? child },
            set: { updated in
                if let i = draft.children.firstIndex(where: { $0.id == child.id }) { draft.children[i] = updated }
            }
        )
    }
}

struct ChildDraftSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var child: OnboardingDraft.ChildDraft
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Text("About your child")
                .font(Typography.sectionTitle)
                .foregroundStyle(Theme.Colors.ink)
            LabeledField(label: "First name", text: $child.firstName, placeholder: "First name", contentType: .givenName)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text("Birthdate").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    Spacer()
                    if !child.firstName.isEmpty {
                        Chip(label: "\(child.firstName), \(child.ageShort)", isSelected: true)
                    }
                }
                DatePicker("Birthdate", selection: $child.dateOfBirth, in: ...Calendar.current.date(byAdding: .month, value: 10, to: Date())!, displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxHeight: 150)
            }
            Spacer()
            Button("Done") { dismiss() }.buttonStyle(.primary(enabled: !child.firstName.isEmpty)).disabled(child.firstName.isEmpty)
            Button("Remove") { onRemove(); dismiss() }.buttonStyle(.secondary)
        }
        .padding(Theme.Spacing.gutter)
        .screenBackground()
    }
}

// MARK: Screen 3 — The first real entry

struct FirstContactScreen: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        OnboardingScreen(eyebrow: "Who to call", hook: "Start with the one thing that matters most. Who should be called first if you can't be?") {
            ContactEntry(contact: $draft.firstContact, showRelationship: true)
        } actions: {
            Button("Continue", action: onContinue)
                .buttonStyle(.primary(enabled: draft.firstContact.isFilled))
                .disabled(!draft.firstContact.isFilled)
        }
    }
}

// MARK: Screen 4 — Pediatrician

struct PediatricianScreen: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    private var hook: String {
        if let youngest = draft.youngest, !youngest.firstName.isEmpty { return "Who's \(youngest.firstName)'s doctor?" }
        return "Who's the kids' doctor?"
    }

    var body: some View {
        OnboardingScreen(eyebrow: "The kids' doctor", hook: hook) {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                ContactEntry(contact: $draft.pediatrician, showRelationship: false, namePlaceholder: "Doctor or practice")
                if draft.children.count > 1 {
                    Toggle("Same doctor for everyone", isOn: $draft.pediatricianForAll)
                        .font(Typography.body)
                        .tint(Theme.Colors.powderBlueDk)
                }
            }
        } actions: {
            Button("Continue", action: onContinue).buttonStyle(.primary(enabled: draft.pediatrician.isFilled)).disabled(!draft.pediatrician.isFilled)
            Button("I'll add this later") { draft.pediatrician = Contact(); onContinue() }.buttonStyle(.secondary)
        }
    }
}

// MARK: Screen 5 — Health insurance

struct InsuranceScreen: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        OnboardingScreen(eyebrow: "Insurance", hook: "Grab your insurance card. This takes 20 seconds.") {
            InsuranceEntry(policy: $draft.healthInsurance, allowVaultSave: false)
        } actions: {
            Button("Continue", action: onContinue).buttonStyle(.primary(enabled: draft.healthInsurance.isFilled)).disabled(!draft.healthInsurance.isFilled)
            Button("I'll add this later") { onContinue() }.buttonStyle(.secondary)
        }
    }
}

// MARK: Screen 6 — The guardian question

struct GuardianScreen: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        OnboardingScreen(eyebrow: "If something happens", hook: "If neither of you could care for your kids, who would?",
                         subline: "This isn't legal paperwork. It's so the people around you know your wishes on the worst day.") {
            ContactEntry(contact: $draft.guardian, showRelationship: true)
        } actions: {
            Button("Continue") { draft.guardianUndecided = false; onContinue() }
                .buttonStyle(.primary(enabled: draft.guardian.isFilled)).disabled(!draft.guardian.isFilled)
            Button("I haven't decided yet") { draft.guardian = Contact(); draft.guardianUndecided = true; onContinue() }
                .buttonStyle(.secondary)
        }
    }
}

// MARK: Screen 7 — Reveal + Sign in with Apple

struct RevealScreen: View {
    @Environment(\.modelContext) private var context
    @Bindable var draft: OnboardingDraft
    let onSaved: (Household) -> Void
    @State private var errorText: String?

    var body: some View {
        let report = draft.previewReport()
        OnboardingScreen(eyebrow: "Your Family File", hook: "This is your Family File.",
                         subline: "It syncs privately to your iCloud. Nothing leaves your Apple account.") {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack {
                    Spacer()
                    CompletenessRing(percent: report.percent)
                    Spacer()
                }
                Card {
                    VStack(spacing: 0) {
                        ForEach(Array(FamilyFileSection.allCases.enumerated()), id: \.element) { i, section in
                            let counts = report.counts(for: section)
                            HStack {
                                BrandIcon(systemName: section.systemImage, isActive: counts.filled > 0)
                                Text(section.title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                Spacer()
                                Text("\(counts.filled) of \(counts.total)").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                            }
                            .padding(.vertical, Theme.Spacing.sm)
                            .reveal(i, baseDelay: 0.9)
                            if section != FamilyFileSection.allCases.last { SandDivider() }
                        }
                    }
                }
                if let next = report.nextToAdd.first {
                    Text(next.nudge)
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(Theme.Colors.powderBlueDk)
                }
                Wordmark().padding(.top, Theme.Spacing.sm)
                if let errorText {
                    Text(errorText).font(Typography.caption).foregroundStyle(Theme.Colors.danger)
                }
            }
        } actions: {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                switch result {
                case .success(let auth):
                    guard let signIn = AppleSignIn.handle(auth) else { return }
                    draft.appleUserID = signIn.userID
                    draft.appleEmail = signIn.email
                    draft.appleGivenName = signIn.fullName?.givenName
                    draft.appleFamilyName = signIn.fullName?.familyName
                    let household = draft.commit(into: context)
                    if let email = signIn.email {
                        Task { await KlaviyoHandoff.subscribe(email: email, youngestChildAge: draft.segment) }
                    }
                    onSaved(household)
                case .failure:
                    errorText = "Sign in didn't finish. Your entries are still here. Try again."
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: Theme.Metrics.primaryButtonHeight)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .accessibilityLabel("Save my Family File")
            Text("Save my Family File with your Apple ID. No email or password to make up.")
                .font(Typography.caption)
                .foregroundStyle(Theme.Colors.sandDeep)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: Screen 8 — Partner invite

struct PartnerInviteScreen: View {
    let household: Household?
    let partnerName: String
    let onContinue: () -> Void
    @State private var sharePayload: SharePayload?
    @State private var errorText: String?

    var body: some View {
        OnboardingScreen(eyebrow: "Your partner", hook: "Your partner should be able to see this too.",
                         subline: "They'll get the same Family File on their phone, and every change syncs both ways.") {
            if let errorText {
                Text(errorText).font(Typography.caption).foregroundStyle(Theme.Colors.danger)
            }
        } actions: {
            Button(partnerName.isEmpty ? "Invite my partner" : "Invite \(partnerName)") {
                guard let household else { onContinue(); return }
                Task {
                    do {
                        let (share, container) = try await CloudSharingService.shared.share(for: household.id, title: "Our Family File")
                        sharePayload = SharePayload(share: share, container: container)
                    } catch {
                        errorText = error.localizedDescription
                    }
                }
            }
            .buttonStyle(.primary)
            Button("Later", action: onContinue).buttonStyle(.secondary)
        }
        .sheet(item: $sharePayload, onDismiss: onContinue) { payload in
            CloudSharingSheet(share: payload.share, container: payload.container)
        }
    }
}

// MARK: Screen 9 — Life Sync setup (calendars + tasks), applied when the trial starts

struct LifeSyncSetupScreen: View {
    @Bindable var draft: OnboardingDraft
    let household: Household?
    let onContinue: () -> Void

    private var partnerName: String { draft.includesPartner && !draft.partnerFirstName.isEmpty ? draft.partnerFirstName : "your partner" }

    var body: some View {
        OnboardingScreen(eyebrow: "Life Sync", hook: "Put both calendars and the house on the same week.",
                         subline: "Pick which calendars \(partnerName) can see, and which chores the app should keep track of. Nothing is written to your calendar.") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                CalendarPickerBlock(granted: $draft.calendarAccessGranted, selected: $draft.selectedCalendarIDs)
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Tasks the app should remember").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    VStack(spacing: Theme.Spacing.sm) {
                        ForEach(TaskTemplate.pack) { t in
                            SelectableRow(title: t.title, detail: t.recurrence.label, systemImage: t.category.systemImage,
                                          isSelected: draft.selectedTemplateKeys.contains(t.key)) {
                                if draft.selectedTemplateKeys.contains(t.key) { draft.selectedTemplateKeys.remove(t.key) } else { draft.selectedTemplateKeys.insert(t.key) }
                            }
                        }
                        if !draft.children.isEmpty {
                            SelectableRow(title: draft.children.count == 1 ? "\(draft.children[0].firstName)'s well-child visit" : "Well-child visits, one per kid",
                                          detail: "Every year, around the birthday", systemImage: "heart.text.square",
                                          isSelected: draft.wantsWellChildVisits) { draft.wantsWellChildVisits.toggle() }
                        }
                    }
                    Text("Shared with \(partnerName). Either of you can check one off.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                HStack { Spacer(); PremiumPill(); Spacer() }
            }
        } actions: {
            Button("Continue") { draft.lifeSyncSkipped = false; onContinue() }.buttonStyle(.primary)
            Button("I'll set this up later") { draft.lifeSyncSkipped = true; onContinue() }.buttonStyle(.secondary)
        }
        .onAppear { draft.calendarAccessGranted = CalendarSyncService.shared.hasAccess }
    }
}

// MARK: Screen 10 — Premium (soft, one time)

struct PremiumOfferScreen: View {
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Bindable var draft: OnboardingDraft
    let household: Household?
    let onContinue: () -> Void

    var body: some View {
        OnboardingScreen(eyebrow: "Petite Home premium", hook: "Now let the app remember for you.") {
            PremiumBullets()
            Text(PaywallSheet.priceLine(entitlements))
                .font(Typography.callout)
                .foregroundStyle(Theme.Colors.sandDeep)
        } actions: {
            if entitlements.purchaseInProgress { PulsingDots().padding(.bottom, Theme.Spacing.xs) }
            Button("Start free trial") {
                Task {
                    if let annual = entitlements.annual { _ = await entitlements.purchase(annual) }
                    stashChoices()
                    if entitlements.isPremium, let household {
                        LifeSyncPending.apply(to: household, adult: appState.currentAdult(in: household), context: context)
                    }
                    onContinue()
                }
            }
            .buttonStyle(.primary)
            Button("Not now") { stashChoices(); onContinue() }.buttonStyle(.secondary)
        }
    }

    /// Keeps the Life Sync choices from the previous screen until premium is on.
    private func stashChoices() {
        guard !draft.lifeSyncSkipped else { return }
        LifeSyncPending.save(calendarIDs: draft.calendarAccessGranted ? draft.selectedCalendarIDs : [],
                             templateKeys: draft.selectedTemplateKeys,
                             wellChild: draft.wantsWellChildVisits)
    }
}

struct PremiumBullets: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            bullet("bell", "Reminds you when passports, car seats, and insurance expire")
            bullet("lock.doc", "Keeps birth certificates and SSN cards in an encrypted vault")
            bullet("calendar", "Life Sync: both calendars and the house tasks on one week, shared with your partner")
        }
    }
    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            BrandIcon(systemName: icon, isActive: true, size: 20).frame(width: 24)
            Text(text).font(Typography.body).foregroundStyle(Theme.Colors.ink).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: Reusable entry blocks

/// Contact picker with manual fallback, plus a relationship dropdown.
struct ContactEntry: View {
    @Binding var contact: Contact
    var showRelationship: Bool
    var namePlaceholder: String = "Full name"
    @State private var showPicker = false

    static let relationships = ["Partner", "Parent", "Sibling", "Friend", "Grandparent", "Neighbor", "Aunt or uncle", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Button {
                Task {
                    _ = await ContactPicker.requestAccess()
                    showPicker = true
                }
            } label: {
                Label("Choose from Contacts", systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.outline)
            LabeledField(label: "Name", text: $contact.name, placeholder: namePlaceholder, contentType: .name)
            LabeledField(label: "Phone", text: $contact.phone, placeholder: "Phone", keyboard: .phonePad, contentType: .telephoneNumber, autocapitalization: .never)
            if showRelationship {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Relationship").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    Picker("Relationship", selection: $contact.relationship) {
                        Text("Choose").tag("")
                        ForEach(Self.relationships, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(Theme.Colors.ink)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(Theme.Colors.white))
                }
            }
        }
        .sheet(isPresented: $showPicker) {
            ContactPicker { picked in
                let relationship = contact.relationship
                contact = picked
                contact.relationship = relationship
            }
            .ignoresSafeArea()
        }
    }
}

/// Insurance card entry: camera scan (on-device, image discarded) plus manual fields.
struct InsuranceEntry: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Binding var policy: InsurancePolicy
    /// Whether "Save to vault" is offered after a scan (Family File screens: yes; onboarding: no).
    var allowVaultSave: Bool
    var onVaultSave: ((UIImage) -> Void)? = nil
    @State private var showCamera = false
    @State private var scanning = false
    @State private var lastImage: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Button {
                showCamera = true
            } label: {
                Label(scanning ? "Reading the card" : "Take a photo of the card", systemImage: "camera")
            }
            .buttonStyle(.outline)
            .disabled(scanning)
            Text("Photo isn't saved. Premium keeps a copy in your vault.")
                .font(Typography.caption)
                .foregroundStyle(Theme.Colors.sandDeep)
            if allowVaultSave, let lastImage {
                Button {
                    if entitlements.isPremium { onVaultSave?(lastImage) } else { appState.showPaywall(.vaultSave) }
                } label: {
                    HStack { Text("Save to vault"); Spacer(); if !entitlements.isPremium { PremiumPill() } }
                }
                .buttonStyle(.outline)
            }
            LabeledField(label: "Carrier", text: $policy.carrier, placeholder: "e.g. Blue Cross")
            LabeledField(label: "Member ID", text: $policy.policyOrMemberID, placeholder: "On the front of the card", autocapitalization: .characters)
            LabeledField(label: "Group number", text: $policy.groupNumber, placeholder: "Group", autocapitalization: .characters)
            LabeledField(label: "Phone on the card", text: $policy.phone, placeholder: "Phone", keyboard: .phonePad, contentType: .telephoneNumber, autocapitalization: .never)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCapture { image in
                showCamera = false
                guard let image else { return }
                scanning = true
                Task {
                    let result = await CardScanner.recognize(image)
                    if !result.carrier.isEmpty { policy.carrier = result.carrier }
                    if !result.memberID.isEmpty { policy.policyOrMemberID = result.memberID }
                    if !result.groupNumber.isEmpty { policy.groupNumber = result.groupNumber }
                    if !result.phone.isEmpty { policy.phone = result.phone }
                    scanning = false
                    // Free tier: the image is gone once this scope ends. Premium may keep it for the vault.
                    lastImage = (allowVaultSave && entitlements.isPremium) ? image : nil
                    if allowVaultSave && !entitlements.isPremium { lastImage = image } // shown only to route to the paywall; never written anywhere
                }
            }
            .ignoresSafeArea()
        }
    }
}

/// A simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width == .infinity ? x : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowHeight + spacing; rowHeight = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
