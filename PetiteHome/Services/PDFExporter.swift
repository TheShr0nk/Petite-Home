import Foundation
import UIKit
import PDFKit

/// Renders the Family File to PDF in the brand palette: cream page, serif
/// section headings, sand rules between sections, powder blue band at the
/// bottom of the cover.
///
/// Free: "Made with Petite Home" footer, no vault attachments.
/// Premium (clean): no footer, "Sealed envelope" cover with the date, vault
/// documents as an appendix.
struct PDFExporter {
    enum Tier { case free, clean }

    struct Attachment {
        let title: String
        let image: UIImage
    }

    let household: Household
    let file: FamilyFile
    let tier: Tier
    var attachments: [Attachment] = []

    private let page = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
    private let margin: CGFloat = 56

    func render() -> Data {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: "The Family File",
            kCGPDFContextCreator as String: "Petite Home Co.",
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: page, format: format)
        let data = renderer.pdfData { ctx in
            drawCover(ctx)
            var cursor = Cursor(ctx: ctx, exporter: self)
            cursor.newPage()
            for section in FamilyFileSection.allCases {
                cursor.heading(section.title)
                for (label, value) in rows(for: section) {
                    cursor.row(label: label, value: value)
                }
                cursor.rule()
            }
            cursor.heading("The kids")
            for child in household.kids {
                cursor.row(label: child.displayName, value: childSummary(child))
            }
            if tier == .clean, !attachments.isEmpty {
                cursor.newPage()
                cursor.heading("Appendix: documents")
                for attachment in attachments {
                    cursor.image(attachment.image, caption: attachment.title)
                }
            }
        }
        Analytics.track(.pdfExported, ["tier": tier == .free ? "free" : "clean"])
        return data
    }

    // MARK: Cover

    private func drawCover(_ ctx: UIGraphicsPDFRendererContext) {
        ctx.beginPage()
        Theme.Colors.uiCream.setFill()
        ctx.fill(page)

        let wordmark = NSAttributedString(string: "PETITE HOME CO.", attributes: [
            .font: Typography.serifUIFont(size: 14),
            .kern: 14 * Theme.Tracking.wordmark,
            .foregroundColor: Theme.Colors.uiSand,
        ])
        wordmark.draw(at: CGPoint(x: margin, y: margin))

        let title = NSAttributedString(string: tier == .clean ? "Sealed envelope" : "The Family File", attributes: [
            .font: Typography.serifUIFont(size: 40),
            .foregroundColor: Theme.Colors.uiInk,
        ])
        title.draw(in: CGRect(x: margin, y: 260, width: page.width - margin * 2, height: 60))

        let subtitleText = tier == .clean
            ? "The Family File for \(household.displayName)."
            : household.displayName
        let subtitle = NSAttributedString(string: subtitleText, attributes: [
            .font: UIFont.systemFont(ofSize: 15),
            .foregroundColor: Theme.Colors.uiSandDeep,
        ])
        subtitle.draw(in: CGRect(x: margin, y: 322, width: page.width - margin * 2, height: 24))

        let dateText = "Prepared \(Self.longDate.string(from: Date()))"
        let date = NSAttributedString(string: dateText, attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: Theme.Colors.uiSandDeep,
        ])
        date.draw(at: CGPoint(x: margin, y: 352))

        if tier == .clean {
            let note = NSAttributedString(string: "Open if something has happened to us and you need to know where things are.", attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: Theme.Colors.uiInk,
            ])
            note.draw(in: CGRect(x: margin, y: 380, width: page.width - margin * 2, height: 40))
        }

        // The powder blue band, matching the base of the pouch.
        Theme.Colors.uiPowderBlue.setFill()
        ctx.fill(CGRect(x: 0, y: page.height - 96, width: page.width, height: 96))
    }

    // MARK: Rows

    private func rows(for section: FamilyFileSection) -> [(String, String)] {
        func c(_ contact: Contact?) -> String { contact?.summary ?? "" }
        func p(_ policy: InsurancePolicy?) -> String {
            guard let policy, policy.isFilled else { return "" }
            var parts = [policy.carrier]
            if !policy.policyOrMemberID.isEmpty { parts.append("ID \(policy.policyOrMemberID)") }
            if !policy.groupNumber.isEmpty { parts.append("Group \(policy.groupNumber)") }
            if !policy.phone.isEmpty { parts.append(policy.phone) }
            return parts.joined(separator: " · ")
        }
        func a(_ refs: [AccountReference]) -> String {
            refs.filter(\.isFilled).map { r in
                var s = r.summary
                if !r.ownerNames.isEmpty { s += " (\(r.ownerNames))" }
                return s
            }.joined(separator: "\n")
        }
        switch section {
        case .emergency:
            var rows: [(String, String)] = []
            for (i, contact) in file.emergencyContacts.enumerated() { rows.append(("Call \(i == 0 ? "first" : "next")", contact.summary)) }
            rows.append(("Preferred hospital", c(file.preferredHospital)))
            rows.append(("Vet or pet sitter", c(file.vetOrPetSitter)))
            rows.append(("Home address", file.homeAddress))
            rows.append(("Spare key", file.spareKeyLocation))
            rows.append(("Gate code", SecureCodes.read(.gateCode) ?? ""))
            rows.append(("Alarm code", SecureCodes.read(.alarmCode) ?? ""))
            return rows
        case .medical:
            var rows: [(String, String)] = [
                ("Health insurance", p(file.healthInsurance)),
                ("Dental insurance", p(file.dentalInsurance)),
                ("Family doctor", c(file.familyDoctor)),
                ("Pharmacy", c(file.pharmacy)),
            ]
            for child in household.kids { rows.append(("\(child.displayName)'s doctor", c(child.pediatrician))) }
            return rows
        case .ifSomethingHappens:
            return [
                ("Who would care for the kids", c(file.designatedGuardian)),
                ("Backup", c(file.backupGuardian)),
                ("Where the will is", file.whereTheWillIs),
                ("Attorney", c(file.attorney)),
                ("Financial advisor", c(file.financialAdvisor)),
                ("Life insurance", file.lifeInsurance.map { p($0) }.filter { !$0.isEmpty }.joined(separator: "\n")),
                ("For whoever has the kids", file.instructionsForKids),
            ]
        case .accounts:
            return [
                ("Bank accounts", a(file.bankAccounts)),
                ("Retirement accounts", a(file.retirementAccounts)),
                ("Mortgage or landlord", c(file.mortgageOrLandlord)),
                ("Utilities", a(file.utilities)),
                ("Recurring bills", a(file.recurringBills)),
                ("Password manager", file.passwordManager),
            ]
        case .homeAndVehicles:
            return [
                ("Home insurance", p(file.homeownersOrRenters)),
                ("Auto insurance", p(file.autoInsurance)),
                ("Vehicles", file.vehicles.filter(\.isFilled).map { v in
                    var s = v.yearMakeModel
                    if !v.plate.isEmpty { s += " · \(v.plate)" }
                    if !v.titleLocation.isEmpty { s += " · title: \(v.titleLocation)" }
                    if !v.loanServicer.isEmpty { s += " · loan: \(v.loanServicer)" }
                    return s
                }.joined(separator: "\n")),
            ]
        }
    }

    private func childSummary(_ child: Child) -> String {
        var parts: [String] = ["Born \(Self.longDate.string(from: child.dateOfBirth))"]
        if !child.allergies.isEmpty { parts.append("Allergies: \(child.allergies.joined(separator: ", "))") }
        if !child.medications.isEmpty { parts.append("Medications: \(child.medications.map { "\($0.name) \($0.dose)" }.joined(separator: ", "))") }
        if let blood = child.bloodType, !blood.isEmpty { parts.append("Blood type \(blood)") }
        if let school = child.school, school.isFilled { parts.append("School: \(school.summary)") }
        if !child.notes.isEmpty { parts.append(child.notes) }
        return parts.joined(separator: "\n")
    }

    static let longDate: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()

    // MARK: Layout cursor

    struct Cursor {
        let ctx: UIGraphicsPDFRendererContext
        let exporter: PDFExporter
        var y: CGFloat = 0
        var pageNumber = 1

        private var page: CGRect { exporter.page }
        private var margin: CGFloat { exporter.margin }
        private var contentWidth: CGFloat { page.width - margin * 2 }
        private var bottom: CGFloat { page.height - margin - 24 }

        mutating func newPage() {
            ctx.beginPage()
            Theme.Colors.uiCream.setFill()
            ctx.fill(page)
            y = margin
            pageNumber += 1
            if exporter.tier == .free {
                let footer = NSAttributedString(string: "Made with Petite Home", attributes: [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: Theme.Colors.uiSandDeep,
                ])
                footer.draw(at: CGPoint(x: margin, y: page.height - margin + 8))
            }
        }

        private mutating func ensure(_ height: CGFloat) {
            if y + height > bottom { newPage() }
        }

        mutating func heading(_ text: String) {
            ensure(48)
            if y > margin { y += 12 }
            let s = NSAttributedString(string: text, attributes: [
                .font: Typography.serifUIFont(size: 20),
                .foregroundColor: Theme.Colors.uiInk,
            ])
            s.draw(at: CGPoint(x: margin, y: y))
            y += 34
        }

        mutating func row(label: String, value: String) {
            let labelStr = NSAttributedString(string: label, attributes: [
                .font: UIFont.systemFont(ofSize: 9, weight: .semibold),
                .foregroundColor: Theme.Colors.uiSandDeep,
                .kern: 9 * Theme.Tracking.caps,
            ])
            let valueText = value.isEmpty ? "—" : value
            let valueStr = NSAttributedString(string: valueText, attributes: [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: value.isEmpty ? Theme.Colors.uiSandDeep : Theme.Colors.uiInk,
            ])
            let valueHeight = valueStr.boundingRect(with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                                                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height
            ensure(14 + valueHeight + 10)
            labelStr.draw(at: CGPoint(x: margin, y: y))
            y += 13
            valueStr.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: valueHeight + 2))
            y += valueHeight + 10
        }

        mutating func rule() {
            ensure(12)
            Theme.Colors.uiSand.withAlphaComponent(0.5).setFill()
            ctx.fill(CGRect(x: margin, y: y, width: contentWidth, height: 1))
            y += 12
        }

        mutating func image(_ image: UIImage, caption: String) {
            let maxHeight: CGFloat = 320
            let scale = min(contentWidth / image.size.width, maxHeight / image.size.height, 1)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            ensure(size.height + 30)
            let cap = NSAttributedString(string: caption, attributes: [
                .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: Theme.Colors.uiSandDeep,
            ])
            cap.draw(at: CGPoint(x: margin, y: y))
            y += 16
            image.draw(in: CGRect(x: margin, y: y, width: size.width, height: size.height))
            y += size.height + 18
        }
    }
}
