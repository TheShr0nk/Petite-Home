import SwiftUI
import SwiftData

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
                "who their doctor is,",
                "or who's supposed to take care of them?",
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
        OnboardingScreen(eyebrow: "Your family", hook: "Let's start with who's at home.") {
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
            .presentationDetents([.large])
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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("About your child")
                        .font(Typography.sectionTitle)
                        .foregroundStyle(Theme.Colors.ink)
                    Text("Just a name and a birthdate. Everything else comes later.")
                        .font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                }
                .padding(.top, Theme.Spacing.lg)
                LabeledField(label: "First name", text: $child.firstName, placeholder: "First name", contentType: .givenName)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Birthdate, or the due date if they're on the way").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    Card {
                        DatePicker("Birthdate", selection: $child.dateOfBirth, in: ...Calendar.current.date(byAdding: .month, value: 10, to: Date())!, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, maxHeight: 170)
                    }
                    if !child.firstName.isEmpty {
                        Chip(label: "\(child.firstName), \(child.ageShort)", systemImage: "checkmark", isSelected: true)
                    }
                }
                Button(child.firstName.isEmpty ? "Add child" : "Add \(child.firstName)") { dismiss() }
                    .buttonStyle(.primary(enabled: !child.firstName.isEmpty)).disabled(child.firstName.isEmpty)
                Button("Remove") { onRemove(); dismiss() }.buttonStyle(.secondary)
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
    }
}

// MARK: Screen 3 — The first real entry

struct FirstContactScreen: View {
    @Bindable var draft: OnboardingDraft
    let onContinue: () -> Void

    var body: some View {
        OnboardingScreen(eyebrow: "Who to call", hook: "First, the one thing that matters most. If you can't be reached, who gets the call?") {
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
                        .tint(Theme.Colors.accentText)
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
        OnboardingScreen(eyebrow: "Insurance", hook: "Go grab your insurance card. This part takes about 20 seconds.") {
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
        OnboardingScreen(eyebrow: "If something happens", hook: "If you couldn't be there for your kids, who would step in?",
                         subline: "This isn't legal paperwork. It's so the people who love you know what you'd want, without having to guess.") {
            ContactEntry(contact: $draft.guardian, showRelationship: true)
        } actions: {
            Button("Continue") { draft.guardianUndecided = false; onContinue() }
                .buttonStyle(.primary(enabled: draft.guardian.isFilled)).disabled(!draft.guardian.isFilled)
            Button("I haven't decided yet") { draft.guardian = Contact(); draft.guardianUndecided = true; onContinue() }
                .buttonStyle(.secondary)
        }
    }
}

// MARK: Screen 7 — Reveal and save

struct RevealScreen: View {
    @Environment(\.modelContext) private var context
    @Bindable var draft: OnboardingDraft
    let onSaved: (Household) -> Void
    @State private var saving = false

    var body: some View {
        let report = draft.previewReport()
        OnboardingScreen(eyebrow: "Your \(AppCopy.binderLower)", hook: "Here's your \(AppCopy.binder).",
                         subline: "It's saved to your own iCloud, and nowhere else.") {
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
                        .foregroundStyle(Theme.Colors.accentText)
                }
                LabeledField(label: "Your first name", text: $draft.firstName, placeholder: "First name", contentType: .givenName)
                LabeledField(label: "Email, if you want the printable version", text: $draft.email, placeholder: "Optional", keyboard: .emailAddress, contentType: .emailAddress, autocapitalization: .never)
                Text("We'll email you the printable version, plus the occasional note from Casey. Leave it blank and we won't send a thing.")
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                Wordmark().padding(.top, Theme.Spacing.sm)
            }
        } actions: {
            if saving { PulsingDots() }
            Button("Save my \(AppCopy.binderLower)") {
                saving = true
                Task {
                    let userID = await CloudIdentity.userID()
                    let household = draft.commit(into: context)
                    household.ownerUserID = userID
                    try? context.save()
                    if !draft.email.isEmpty {
                        Task { await KlaviyoHandoff.subscribe(email: draft.email, youngestChildAge: draft.segment) }
                    }
                    await EntitlementStore.shared.identify(userID: userID)
                    saving = false
                    onSaved(household)
                }
            }
            .buttonStyle(.primary(enabled: !saving)).disabled(saving)
            Text(CloudIdentity.isICloudAvailable ? "It saves to your iCloud. No account to make, no password to remember." : "iCloud is off on this phone, so for now this stays right here. Turn it on in Settings whenever you want to sync and share.")
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
        OnboardingScreen(eyebrow: "Your partner", hook: "Your partner should have this too.",
                         subline: "They get the same \(AppCopy.binderLower) on their phone. When one of you changes something, you both see it.") {
            if let errorText {
                Text(errorText).font(Typography.caption).foregroundStyle(Theme.Colors.danger)
            }
        } actions: {
            Button(partnerName.isEmpty ? "Invite my partner" : "Invite \(partnerName)") {
                guard let household else { onContinue(); return }
                Task {
                    do {
                        let (share, container) = try await CloudSharingService.shared.share(for: household.uuid, title: "Our \(AppCopy.binder)")
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
        OnboardingScreen(eyebrow: AppCopy.planner, hook: "Get both of your calendars, and the house, onto one week.",
                         subline: "Pick which calendars \(partnerName) can see, and which chores you'd like a nudge about. Nothing gets written to your calendar unless you turn that on later.") {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                CalendarPickerBlock(granted: $draft.calendarAccessGranted, selected: $draft.selectedCalendarIDs)
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Chores you'd like a nudge about").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ForEach(TaskTemplate.grouped(), id: \.0) { cadence, templates in
                            Eyebrow(text: cadence.label).padding(.top, Theme.Spacing.xs)
                            ForEach(templates) { t in
                                SelectableRow(title: t.title, detail: t.recurrence.label + (t.weekday.map { " · \(Calendar.current.weekdaySymbols[$0 - 1])" } ?? ""), systemImage: t.category.systemImage,
                                              isSelected: draft.selectedTemplateKeys.contains(t.key)) {
                                    if draft.selectedTemplateKeys.contains(t.key) { draft.selectedTemplateKeys.remove(t.key) } else { draft.selectedTemplateKeys.insert(t.key) }
                                }
                            }
                        }
                        Eyebrow(text: "Every year").padding(.top, Theme.Spacing.xs)
                        if !draft.children.isEmpty {
                            SelectableRow(title: draft.children.count == 1 ? "\(draft.children[0].firstName)'s well-child visit" : "Well-child visits, one per kid",
                                          detail: "Every year, around the birthday", systemImage: "heart.text.square",
                                          isSelected: draft.wantsWellChildVisits) { draft.wantsWellChildVisits.toggle() }
                        }
                    }
                    Text("Shared with \(partnerName). Either of you can check one off.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                PhoneExportRows(reminders: $draft.wantsRemindersExport, calendar: $draft.wantsCalendarExport)
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
    @State private var showPlans = false

    var body: some View {
        OnboardingScreen(eyebrow: "Petite Home premium", hook: "Now let us do the remembering.") {
            PremiumBullets()
            Text("Monthly or yearly. Your first week is $0.99 either way, then the regular price. Cancel whenever you like.")
                .font(Typography.callout)
                .foregroundStyle(Theme.Colors.sandDeep)
        } actions: {
            Button(entitlements.usesLocalTrial ? "Unlock while we're testing" : "Start my premium subscription") {
                if entitlements.usesLocalTrial {
                    entitlements.startLocalTrial()
                    finish()
                } else {
                    showPlans = true
                }
            }
            .buttonStyle(.primary)
            Text("Petite Home is a subscription. Everything you've entered is saved on your phone and in your iCloud either way.")
                .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep).multilineTextAlignment(.center)
        }
        .sheet(isPresented: $showPlans, onDismiss: { if entitlements.isPremium { finish() } }) {
            PaywallSheet(gate: .onboarding)
        }
        .onChange(of: entitlements.isPremium) { _, on in if on { finish() } }
    }

    /// Stashes the Planner choices, applies them if premium is on, and moves to Home.
    private func finish() {
        stashChoices()
        if entitlements.isPremium, let household {
            LifeSyncPending.apply(to: household, adult: appState.currentAdult(in: household), context: context)
        }
        onContinue()
    }

    /// Keeps the Life Sync choices from the previous screen until premium is on.
    private func stashChoices() {
        guard !draft.lifeSyncSkipped else { return }
        LifeSyncPending.save(calendarIDs: draft.calendarAccessGranted ? draft.selectedCalendarIDs : [],
                             templateKeys: draft.selectedTemplateKeys,
                             wellChild: draft.wantsWellChildVisits,
                             remindersExport: draft.wantsRemindersExport,
                             calendarExport: draft.wantsCalendarExport)
    }
}

struct PremiumBullets: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            bullet("bell", "A heads-up before passports, car seats, and insurance run out")
            bullet("lock.doc", "Birth certificates and Social Security cards, locked in your vault")
            bullet("calendar", "Both of your calendars, the chores, dinner, and date nights on one week you can both see")
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
                // CNContactPickerViewController runs out of process; the app only receives the one
                // contact the user picks, so there is no permission to ask for.
                showPicker = true
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

// MARK: Phone export rows (shared by the owner's Planner step and the partner welcome)

/// Two opt-in rows for this phone's own Reminders and Calendar apps. The permission
/// is asked the moment a row is turned on, so the system prompt has context.
struct PhoneExportRows: View {
    @Binding var reminders: Bool
    @Binding var calendar: Bool
    @State private var denied: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Also on this phone").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                SelectableRow(title: "Chores in my Reminders app", detail: "A list called Petite Home", systemImage: "checklist", isSelected: reminders) {
                    if reminders { reminders = false; return }
                    Task {
                        if await PhoneSyncService.shared.requestRemindersAccess() { reminders = true; denied = nil }
                        else { denied = "Reminders access is off. You can turn it on later in Settings → Privacy & Security → Reminders." }
                    }
                }
                SelectableRow(title: "Plans and meals in my Calendar app", detail: "A calendar called Petite Home", systemImage: "calendar.badge.plus", isSelected: calendar) {
                    if calendar { calendar = false; return }
                    Task {
                        if await PhoneSyncService.shared.requestCalendarAccess() { calendar = true; denied = nil }
                        else { denied = "Calendar access is off. You can turn it on later in Settings → Privacy & Security → Calendars." }
                    }
                }
            }
            Text(denied ?? "Both say they came from Petite Home. Check a chore off there and the app knows.")
                .font(Typography.caption)
                .foregroundStyle(denied == nil ? Theme.Colors.sandDeep : Theme.Colors.danger)
        }
    }
}
