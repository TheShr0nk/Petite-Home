import SwiftUI
import SwiftData

/// One of the five sections: a list of rows, each opening its editor.
struct FamilyFileSectionView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Bindable var household: Household
    @Bindable var file: FamilyFile
    let section: FamilyFileSection
    @State private var editing: FamilyFileField?

    private var fields: [FamilyFileField] { FamilyFileField.allCases.filter { $0.section == section } }

    var body: some View {
        let report = Completeness.report(file: file, household: household)
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                Text(sectionIntro)
                    .font(Typography.body)
                    .foregroundStyle(Theme.Colors.sandDeep)
                    .fixedSize(horizontal: false, vertical: true)
                Card {
                    VStack(spacing: 0) {
                        ForEach(fields) { field in
                            FieldRow(label: field.label, value: value(for: field), instruction: field.instruction) {
                                editing = field
                            }
                            if field != fields.last { SandDivider() }
                        }
                    }
                }
                if section == .ifSomethingHappens {
                    Text("This isn't legal paperwork. It's so the people around you know your wishes.")
                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                if section == .accounts {
                    Text("Names and where things are. Never a password, PIN or full account number.")
                        .font(Typography.caption).foregroundStyle(Theme.Colors.sandDeep)
                }
                if report.counts(for: section).filled == report.counts(for: section).total {
                    Label("This section is done", systemImage: "checkmark.circle")
                        .font(Typography.callout).foregroundStyle(Theme.Colors.success)
                }
            }
            .padding(.horizontal, Theme.Spacing.gutter)
            .padding(.vertical, Theme.Spacing.lg)
        }
        .screenBackground()
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $editing, onDismiss: save) { field in
            FieldEditor(household: household, file: file, field: field)
                .presentationBackground(Theme.Colors.cream)
        }
        .onAppear {
            if let pending = appState.pendingField, pending.section == section {
                editing = pending
                appState.pendingField = nil
            }
        }
    }

    private var sectionIntro: String {
        switch section {
        case .emergency: return "Who to call, where to go, how to get in."
        case .medical: return "Insurance and doctors, so nobody has to dig."
        case .ifSomethingHappens: return "Who would step in, and where the paperwork is."
        case .accounts: return "Where the money is and who to call about it."
        case .homeAndVehicles: return "Insurance, cars and the title in the drawer."
        }
    }

    private func save() {
        file.updatedAt = Date()
        try? context.save()
        ExpirationScheduler.sync(household: household, isPremium: EntitlementStore.shared.isPremium)
    }

    private func value(for field: FamilyFileField) -> String? {
        switch field {
        case .emergencyContactFirst: return file.emergencyContacts.first?.summary
        case .emergencyContactSecond: return file.emergencyContacts.count > 1 ? file.emergencyContacts[1].summary : nil
        case .preferredHospital: return file.preferredHospital?.summary
        case .homeAddress: return file.homeAddress
        case .keysAndCodes:
            var parts: [String] = []
            if !file.spareKeyLocation.isEmpty { parts.append("Key: \(file.spareKeyLocation)") }
            if file.hasGateCode { parts.append("Gate code set") }
            if file.hasAlarmCode { parts.append("Alarm code set") }
            return parts.joined(separator: " · ")
        case .vetOrPetSitter: return file.vetOrPetSitter?.summary
        case .healthInsurance: return file.healthInsurance.summary
        case .pediatrician:
            let kids = household.kids
            if kids.isEmpty { return "Add a child first" }
            let named = kids.compactMap { k -> String? in
                guard let p = k.pediatrician, p.isFilled else { return nil }
                return "\(k.displayName): \(p.name)"
            }
            return named.joined(separator: " · ")
        case .familyDoctor: return file.familyDoctor?.summary
        case .pharmacy: return file.pharmacy?.summary
        case .dentalInsurance: return file.dentalInsurance?.summary
        case .designatedGuardian: return file.designatedGuardian?.summary
        case .backupGuardian: return file.backupGuardian?.summary
        case .whereTheWillIs: return file.whereTheWillIs
        case .attorney: return file.attorney?.summary
        case .financialAdvisor: return file.financialAdvisor?.summary
        case .lifeInsurance: return file.lifeInsurance.filter(\.isFilled).map(\.summary).joined(separator: " · ")
        case .instructionsForKids: return file.instructionsForKids
        case .bankAccounts: return file.bankAccounts.filter(\.isFilled).map(\.summary).joined(separator: " · ")
        case .retirementAccounts: return file.retirementAccounts.filter(\.isFilled).map(\.summary).joined(separator: " · ")
        case .mortgageOrLandlord: return file.mortgageOrLandlord?.summary
        case .utilities: return file.utilities.filter(\.isFilled).map(\.summary).joined(separator: " · ")
        case .recurringBills: return file.recurringBills.filter(\.isFilled).map(\.summary).joined(separator: " · ")
        case .passwordManager: return file.passwordManager
        case .homeownersOrRenters: return file.homeownersOrRenters?.summary
        case .autoInsurance: return file.autoInsurance?.summary
        case .vehicles: return file.vehicles.filter(\.isFilled).map(\.yearMakeModel).joined(separator: " · ")
        }
    }
}
