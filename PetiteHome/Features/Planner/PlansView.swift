import SwiftUI
import SwiftData

/// Plans: date nights, outings, trips, visitors. Who's going, whether the
/// kids need someone, and who that someone is. Premium, inside the Planner.
struct PlansView: View {
    @Environment(AppState.self) private var appState
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.modelContext) private var context
    @Bindable var household: Household
    @State private var editing: FamilyPlan?
    @State private var showNew = false
    @State private var newKind: PlanKind = .dateNight
    @State private var newDate: Date? = nil
    @State private var showSitters = false

    private var upcoming: [FamilyPlan] { (household.plans ?? []).filter { !$0.isPast }.sorted { $0.startDate < $1.startDate } }
    private var past: [FamilyPlan] { (household.plans ?? []).filter(\.isPast).sorted { $0.startDate > $1.startDate }.prefix(5).map { $0 } }
    private var freeEvenings: [FreeEveningFinder.Evening] {
        Array(FreeEveningFinder.find(events: household.calendarEvents ?? [], plans: household.plans ?? []).prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                if entitlements.isPremium { content } else { LockedPreview(onTap: { appState.showPaywall(.lifeSync) }) { sample } }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .sheet(item: $editing) { plan in PlanEditorSheet(household: household, plan: plan, kind: plan.kind, date: plan.startDate) }
        .sheet(isPresented: $showNew) { PlanEditorSheet(household: household, plan: nil, kind: newKind, date: newDate ?? defaultDate) }
        .sheet(isPresented: $showSitters) { SitterRosterSheet(household: household) }
    }

    private var defaultDate: Date {
        let cal = Calendar.current
        let sat = cal.nextDate(after: Date(), matching: DateComponents(hour: 19, weekday: 7), matchingPolicy: .nextTime) ?? Date()
        return sat
    }

    @ViewBuilder private var content: some View {
        dateNightCard
        HStack(spacing: Theme.Spacing.sm) {
            ForEach([PlanKind.outing, .trip, .appointment, .visitors]) { kind in
                Chip(label: kind.label, systemImage: kind.systemImage) { newKind = kind; newDate = nil; showNew = true }
            }
        }
        SectionHeader(title: "Coming up", detail: upcoming.isEmpty ? nil : "\(upcoming.count)")
        if upcoming.isEmpty {
            Card { Text("Nothing planned yet. Pick a date night above, or add an outing.").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep) }
        } else {
            ForEach(upcoming) { plan in PlanCard(plan: plan, household: household) { editing = plan } }
        }
        BrandDivider()
        HStack {
            SectionHeader(title: "Sitters", detail: household.sitters.isEmpty ? nil : "\(household.sitters.count)")
            Button("Manage") { showSitters = true }.font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.powderBlueDk)
        }
        if household.sitters.isEmpty {
            EmptyStateRow(instruction: "Add the people who've watched the kids", systemImage: "person.badge.plus") { showSitters = true }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.md) {
                    ForEach(household.sitters) { s in
                        VStack(spacing: Theme.Spacing.xs) {
                            AvatarView(initial: s.name, kind: .adult, size: 48)
                            Text(s.name.split(separator: " ").first.map(String.init) ?? s.name).font(Typography.caption).foregroundStyle(Theme.Colors.ink)
                            if s.timesUsed > 0 { Text("\(s.timesUsed)×").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep) }
                        }
                    }
                }
            }
        }
        if !past.isEmpty {
            SectionHeader(title: "Recently")
            ForEach(past) { plan in
                HStack {
                    BrandIcon(systemName: plan.kind.systemImage)
                    Text(plan.displayTitle).font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                    Spacer()
                    Text(plan.startDate.formatted(date: .abbreviated, time: .omitted)).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
            }
        }
    }

    /// "Pick a date night": three free evenings from both calendars, one tap each.
    private var dateNightCard: some View {
        Card(background: Theme.Colors.powderBlueMist) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    BrandIcon(systemName: "moon.stars", isActive: true, size: 20)
                    Text("Pick a date night").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                }
                let me = appState.currentAdult(in: household)
                let synced = (me?.calendarSyncEnabled ?? false) || (household.partner?.calendarSyncEnabled ?? false)
                Text(synced ? "Evenings with nothing on either calendar, weekends first." : "Turn on calendar sync and these become the evenings you're both free.")
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                if freeEvenings.isEmpty {
                    Text("The next two weeks are full. Pick a day anyway.").font(Typography.body).foregroundStyle(Theme.Colors.sandDeep)
                } else {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(freeEvenings) { evening in
                            Button {
                                newKind = .dateNight; newDate = evening.date; showNew = true
                            } label: {
                                VStack(spacing: 2) {
                                    Text(evening.date.formatted(.dateTime.weekday(.abbreviated))).font(Typography.capsLabel).textCase(.uppercase).foregroundStyle(Theme.Colors.sandDeep)
                                    Text(evening.date.formatted(.dateTime.day())).font(Typography.serif(22)).foregroundStyle(Theme.Colors.ink)
                                    Text(evening.date.formatted(.dateTime.month(.abbreviated))).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.sm)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(Theme.Colors.cream))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Button("Another day") { newKind = .dateNight; newDate = nil; showNew = true }.buttonStyle(.secondary)
            }
        }
    }

    private var sample: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            Card(background: Theme.Colors.powderBlueMist) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Pick a date night").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                    Text("Evenings with nothing on either calendar, weekends first.").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(["Sat 12", "Fri 18", "Sat 19"], id: \.self) { d in
                            Text(d).font(Typography.serif(18)).frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.md)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(Theme.Colors.cream))
                        }
                    }
                }
            }
            Card {
                HStack(spacing: Theme.Spacing.md) {
                    BrandIcon(systemName: "moon.stars", isActive: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dinner at Lucia's").font(Typography.body).foregroundStyle(Theme.Colors.ink)
                        Text("Sat · 7:00 PM · Sitter confirmed: Grandma").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    }
                }
            }
        }
    }
}

struct PlanCard: View {
    let plan: FamilyPlan
    let household: Household
    let onTap: () -> Void

    private var sitter: SitterProfile? { household.sitters.first { $0.id == plan.sitterID } }
    private var tone: Color {
        switch plan.sitterStatus {
        case .needed: return Theme.Colors.danger
        case .asked: return Theme.Colors.warn
        case .confirmed: return Theme.Colors.success
        case .notNeeded: return Theme.Colors.sandDeep
        }
    }

    var body: some View {
        Button(action: onTap) {
            Card {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ZStack {
                        Circle().fill(Theme.Colors.powderBlue.opacity(0.35))
                        Image(systemName: plan.kind.systemImage).font(.system(size: 15, weight: .regular)).foregroundStyle(Theme.Colors.ink)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(plan.displayTitle).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                        Text(plan.startDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()) + (plan.location.isEmpty ? "" : " · \(plan.location)"))
                            .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        HStack(spacing: 6) {
                            Circle().fill(tone).frame(width: 6, height: 6)
                            Text(sitterLine).font(Typography.caption).foregroundStyle(plan.needsAttention ? tone : Theme.Colors.sandDeep)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var sitterLine: String {
        switch plan.sitterStatus {
        case .notNeeded: return "Kids come along"
        case .needed: return "Need a sitter"
        case .asked: return "Asked \(sitter?.name ?? "a sitter")"
        case .confirmed: return "\(sitter?.name ?? "Sitter") is watching the kids"
        }
    }
}

// MARK: Editor

struct PlanEditorSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var household: Household
    let plan: FamilyPlan?
    @State var kind: PlanKind
    @State var date: Date

    @State private var title = ""
    @State private var hasEnd = true
    @State private var end = Date()
    @State private var location = ""
    @State private var notes = ""
    @State private var adultIDs: Set<UUID> = []
    @State private var childIDs: Set<UUID> = []
    @State private var sitterStatus: SitterStatus = .needed
    @State private var sitterID: UUID?
    @State private var reminder = true
    @State private var showSitters = false
    @State private var confirmDelete = false

    private var sitter: SitterProfile? { household.sitters.first { $0.id == sitterID } }

    var body: some View {
        NavigationStack {
            EditorScroll(title: plan == nil ? kind.label : "Plan") {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("What kind").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach(PlanKind.allCases) { k in Chip(label: k.label, systemImage: k.systemImage, isSelected: kind == k) { kind = k; if plan == nil { sitterStatus = k.usuallyNeedsSitter ? .needed : .notNeeded } } }
                    }
                }
                LabeledField(label: "What", text: $title, placeholder: kind == .dateNight ? "e.g. Dinner at Lucia's" : "e.g. Zoo with the cousins", autocapitalization: .sentences)
                DatePicker("Starts", selection: $date).font(Typography.body).tint(Theme.Colors.powderBlueDk)
                Toggle("Ends", isOn: $hasEnd).font(Typography.body).tint(Theme.Colors.powderBlueDk)
                if hasEnd { DatePicker("Back by", selection: $end, in: date...).font(Typography.body).tint(Theme.Colors.powderBlueDk) }
                LabeledField(label: "Where", text: $location, placeholder: "Place or address", contentType: .location, autocapitalization: .words)

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Who's going").font(Typography.label).foregroundStyle(Theme.Colors.sandDeep)
                    FlowLayout(spacing: Theme.Spacing.sm) {
                        ForEach(household.adults) { a in Chip(label: a.displayName, isSelected: adultIDs.contains(a.uuid)) { toggle(&adultIDs, a.uuid) } }
                        ForEach(household.kids) { c in Chip(label: c.displayName, isSelected: childIDs.contains(c.uuid)) { toggle(&childIDs, c.uuid); sitterStatus = childIDs.count == household.kids.count ? .notNeeded : (sitterStatus == .notNeeded ? .needed : sitterStatus) } }
                    }
                }

                if !household.kids.isEmpty {
                    Card(background: sitterStatus == .notNeeded ? Theme.Colors.creamDeep : Theme.Colors.powderBlueMist) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            Text("The kids").font(Typography.sectionTitle).foregroundStyle(Theme.Colors.ink)
                            FlowLayout(spacing: Theme.Spacing.sm) {
                                ForEach(SitterStatus.allCases) { s in Chip(label: s.label, isSelected: sitterStatus == s) { sitterStatus = s } }
                            }
                            if sitterStatus != .notNeeded {
                                if household.sitters.isEmpty {
                                    Button { showSitters = true } label: { Label("Add a sitter", systemImage: "person.badge.plus") }.buttonStyle(.outline)
                                } else {
                                    VStack(spacing: Theme.Spacing.sm) {
                                        ForEach(household.sitters) { s in
                                            SelectableRow(title: s.name, detail: [s.rateNotes, s.timesUsed > 0 ? "\(s.timesUsed)× before" : ""].filter { !$0.isEmpty }.joined(separator: " · "),
                                                          isSelected: sitterID == s.id) { sitterID = sitterID == s.id ? nil : s.id }
                                        }
                                        Button("Add someone else") { showSitters = true }.buttonStyle(.secondary)
                                    }
                                }
                                if let sitter, !sitter.contact.phone.isEmpty, let planForText = draftPlan() {
                                    HStack(spacing: Theme.Spacing.sm) {
                                        Link(destination: smsURL(sitter.contact.phone, body: SitterSheet.askText(plan: planForText, sitterName: sitter.name))) {
                                            Label("Ask \(sitter.name.split(separator: " ").first.map(String.init) ?? sitter.name)", systemImage: "message")
                                        }.buttonStyle(.outline)
                                        ShareLink(item: SitterSheet.text(plan: planForText, household: household, sitterName: sitter.name)) {
                                            Label("Sitter sheet", systemImage: "doc.text")
                                        }.buttonStyle(.outline)
                                            .simultaneousGesture(TapGesture().onEnded { Analytics.track(.sitterSheetSent) })
                                    }
                                    Text("The sitter sheet is bedtime notes, allergies, meds and who to call, pulled from the \(AppCopy.binder). Never codes or accounts.")
                                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                                }
                            }
                        }
                    }
                }
                LabeledTextEditor(label: "Notes", text: $notes, hint: "Reservation at 7:30. Bring the stroller.")
                Toggle("Remind us the day before", isOn: $reminder).font(Typography.body).tint(Theme.Colors.powderBlueDk)
                Button(plan == nil ? "Add to the \(AppCopy.planner.lowercased())" : "Save") { save() }.buttonStyle(.primary)
                if plan != nil {
                    Button("Cancel this plan", role: .destructive) { confirmDelete = true }.font(Typography.button).foregroundStyle(Theme.Colors.danger).frame(maxWidth: .infinity)
                }
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
        .sheet(isPresented: $showSitters) { SitterRosterSheet(household: household) }
        .confirmationDialog("Cancel this plan?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Cancel the plan", role: .destructive) { if let plan { NotificationService.shared.cancelTaskDue(id: plan.uuid); context.delete(plan); try? context.save() }; dismiss() }
        }
        .onAppear {
            end = Calendar.current.date(byAdding: .hour, value: 3, to: date) ?? date
            adultIDs = Set(household.adults.map(\.uuid))
            if let plan {
                title = plan.title; kind = plan.kind; date = plan.startDate; hasEnd = plan.endDate != nil; end = plan.endDate ?? end
                location = plan.location; notes = plan.notes; adultIDs = Set(plan.adultIDs); childIDs = Set(plan.childIDs)
                sitterStatus = plan.sitterStatus; sitterID = plan.sitterID; reminder = plan.reminderEnabled
            } else if !kind.usuallyNeedsSitter {
                childIDs = Set(household.kids.map(\.uuid)); sitterStatus = .notNeeded
            }
        }
    }

    private func toggle(_ set: inout Set<UUID>, _ id: UUID) { if set.contains(id) { set.remove(id) } else { set.insert(id) } }

    private func smsURL(_ phone: String, body: String) -> URL {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "sms:\(digits)&body=\(encoded)") ?? URL(string: "sms:")!
    }

    /// An unsaved copy for the sitter texts, so the sheet works before Save.
    private func draftPlan() -> FamilyPlan? {
        let p = FamilyPlan(title: title, kind: kind, startDate: date)
        p.endDate = hasEnd ? end : nil; p.location = location; p.childIDs = Array(childIDs)
        return p
    }

    private func save() {
        let target = plan ?? FamilyPlan(title: title, kind: kind, startDate: date)
        target.title = title; target.kind = kind; target.startDate = date; target.endDate = hasEnd ? end : nil
        target.location = location; target.notes = notes; target.adultIDs = Array(adultIDs); target.childIDs = Array(childIDs)
        target.sitterStatus = sitterStatus; target.sitterID = sitterStatus == .notNeeded ? nil : sitterID; target.reminderEnabled = reminder
        if plan == nil { household.plans?.append(target); Analytics.track(.planCreated, ["kind": kind.rawValue, "sitter": sitterStatus.rawValue]) }
        if sitterStatus == .confirmed, let i = household.sitters.firstIndex(where: { $0.id == sitterID }), plan?.sitterStatus != .confirmed {
            household.sitters[i].timesUsed += 1; household.sitters[i].lastUsedAt = date
        }
        if reminder, let dayBefore = Calendar.current.date(byAdding: .day, value: -1, to: date) {
            NotificationService.shared.scheduleTaskDue(id: target.uuid, title: "Tomorrow: \(target.displayTitle)", due: dayBefore)
        } else {
            NotificationService.shared.cancelTaskDue(id: target.uuid)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: Sitter roster

struct SitterRosterSheet: View {
    @Environment(\.modelContext) private var context
    @Bindable var household: Household
    @State private var adding = false
    @State private var draft = SitterProfile()

    var body: some View {
        NavigationStack {
            EditorScroll(title: "Sitters") {
                Text("Grandparents, the neighbor's teenager, the sitter from the agency. Both of you see the same list.")
                    .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                ForEach($household.sitters) { $s in
                    Card {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            HStack { AvatarView(initial: s.name, kind: .adult, size: 36); Text(s.name).font(Typography.bodyEmphasis).foregroundStyle(Theme.Colors.ink); Spacer()
                                Button("Remove") { household.sitters.removeAll { $0.id == s.id } }.font(Typography.caption).foregroundStyle(Theme.Colors.danger) }
                            LabeledField(label: "Phone", text: $s.contact.phone, placeholder: "Phone", keyboard: .phonePad, autocapitalization: .never)
                            LabeledField(label: "Rate and how to ask", text: $s.rateNotes, placeholder: "$20/hr, text a week ahead", autocapitalization: .sentences)
                            LabeledField(label: "Notes", text: $s.notes, placeholder: "Great with Theo, doesn't drive", autocapitalization: .sentences)
                        }
                    }
                }
                if adding {
                    Card(background: Theme.Colors.powderBlueMist) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            ContactEntry(contact: $draft.contact, showRelationship: true, namePlaceholder: "Sitter's name")
                            LabeledField(label: "Rate and how to ask", text: $draft.rateNotes, placeholder: "$20/hr, text a week ahead", autocapitalization: .sentences)
                            Button("Add") { household.sitters.append(draft); draft = SitterProfile(); adding = false; try? context.save() }
                                .buttonStyle(.primary(enabled: draft.contact.isFilled)).disabled(!draft.contact.isFilled)
                        }
                    }
                } else {
                    Button { adding = true } label: { Label("Add a sitter", systemImage: "person.badge.plus") }.buttonStyle(.outline)
                }
            }
            .screenBackground()
            .toolbar { DoneToolbarItem() }
        }
        .presentationBackground(Theme.Colors.cream)
        .onDisappear { try? context.save() }
    }
}
