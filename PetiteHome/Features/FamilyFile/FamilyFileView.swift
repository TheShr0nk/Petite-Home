import SwiftUI
import SwiftData

/// The Family File tab: the ring, then the five sections.
struct FamilyFileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Bindable var household: Household
    @State private var path = NavigationPath()
    @State private var showExport = false
    @State private var showTrusted = false

    var body: some View {
        NavigationStack(path: $path) {
            if let file = household.familyFile {
                content(file: file)
            } else {
                ProgressView().onAppear { household.familyFile = FamilyFile(); try? context.save() }
            }
        }
    }

    private func content(file: FamilyFile) -> some View {
        let report = Completeness.report(file: file, household: household)
        return Group {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    HStack(alignment: .center, spacing: Theme.Spacing.xl) {
                        CompletenessRing(percent: report.percent, size: 120)
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(household.displayName)
                                .font(Typography.title)
                                .foregroundStyle(Theme.Colors.ink)
                            if let next = report.nextToAdd.first {
                                Button(next.nudge) { appState.open(next) }
                                    .font(Typography.bodyEmphasis)
                                    .foregroundStyle(Theme.Colors.powderBlueDk)
                            } else {
                                Text("Everything's here.")
                                    .font(Typography.body)
                                    .foregroundStyle(Theme.Colors.success)
                            }
                        }
                    }
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(FamilyFileSection.allCases) { section in
                                let counts = report.counts(for: section)
                                NavigationLink(value: section) {
                                    HStack(spacing: Theme.Spacing.md) {
                                        BrandIcon(systemName: section.systemImage, isActive: counts.filled == counts.total)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(section.title).font(Typography.body).foregroundStyle(Theme.Colors.ink)
                                            Text("\(counts.filled) of \(counts.total) added").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.Colors.sandDeep)
                                    }
                                    .padding(Theme.Spacing.lg)
                                }
                                .buttonStyle(.plain)
                                if section != FamilyFileSection.allCases.last { SandDivider().padding(.leading, Theme.Spacing.lg + 30) }
                            }
                        }
                    }
                    SectionHeader(title: "The kids")
                    KidsRow(household: household)
                    SectionHeader(title: "Share it")
                    VStack(spacing: Theme.Spacing.sm) {
                        Button { showExport = true } label: { Label("Export as PDF", systemImage: "arrow.up.doc") }.buttonStyle(.outline)
                        Button { showTrusted = true } label: {
                            HStack { Label("Share with someone I trust", systemImage: "person.badge.key"); Spacer(); PremiumLockIfNeeded() }
                        }.buttonStyle(.outline)
                    }
                }
                .padding(.horizontal, Theme.Spacing.gutter)
                .padding(.vertical, Theme.Spacing.lg)
            }
            .screenBackground()
            .navigationTitle(AppCopy.binder)
            .toolbar { SettingsToolbarItem() }
            .navigationDestination(for: FamilyFileSection.self) { section in
                FamilyFileSectionView(household: household, file: file, section: section)
            }
            .navigationDestination(for: Child.self) { child in ChildProfileView(child: child) }
            .sheet(isPresented: $showExport) { ExportOptionsSheet(household: household) }
            .sheet(isPresented: $showTrusted) { TrustedSharingSheet(household: household) }
            .onChange(of: appState.pendingField, initial: true) { _, field in
                guard let field else { return }
                path = NavigationPath()
                path.append(field.section)
            }
        }
    }
}

/// The gear in the top-right. Settings is a sheet, not a tab.
struct SettingsToolbarItem: ToolbarContent {
    @Environment(AppState.self) private var appState
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { appState.showSettings = true } label: {
                Image(systemName: "gearshape").foregroundStyle(Theme.Colors.sandDeep)
            }
            .accessibilityLabel("Settings")
        }
    }
}

struct PremiumLockIfNeeded: View {
    @Environment(EntitlementStore.self) private var entitlements
    var body: some View {
        if !entitlements.isPremium { PremiumPill() }
    }
}

struct KidsRow: View {
    let household: Household
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.md) {
                ForEach(household.kids, id: \.uuid) { child in
                    NavigationLink(value: child) {
                        VStack(spacing: Theme.Spacing.xs) {
                            AvatarView(initial: child.initial, kind: .child, size: 52)
                            Text(child.displayName).font(Typography.caption).foregroundStyle(Theme.Colors.ink)
                            Text(child.ageShort).font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                        }
                    }
                    .buttonStyle(.plain)
                }
                NavigationLink(value: "addChild") {
                    VStack(spacing: Theme.Spacing.xs) {
                        ZStack {
                            Circle().stroke(Theme.Colors.sand, lineWidth: 1).frame(width: 52, height: 52)
                            Image(systemName: "plus").foregroundStyle(Theme.Colors.sandDeep)
                        }
                        Text("Add a child").font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationDestination(for: String.self) { key in
            if key == "addChild" { AddChildView(household: household) }
        }
    }
}
