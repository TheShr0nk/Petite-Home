import UIKit
import SwiftUI

/// What goes out when someone shares a recipe: a portrait card in the brand
/// palette (sized for Instagram stories and Messages), plus the recipe as
/// plain text for anywhere that only takes words.
enum RecipeShare {
    static let cardSize = CGSize(width: 1080, height: 1350)

    static func text(for recipe: Recipe) -> String {
        var lines: [String] = [recipe.title]
        if !recipe.summary.isEmpty { lines.append(recipe.summary) }
        lines.append("")
        lines.append("Ingredients")
        lines.append(contentsOf: recipe.ingredients.map { "· \($0)" })
        if !recipe.steps.isEmpty {
            lines.append("")
            lines.append("Steps")
            lines.append(contentsOf: recipe.steps.enumerated().map { "\($0.offset + 1). \($0.element)" })
        }
        if !recipe.notes.isEmpty { lines.append(""); lines.append(recipe.notes) }
        if !recipe.sourceURL.isEmpty { lines.append(""); lines.append("From \(recipe.sourceURL)") }
        lines.append("")
        lines.append("Shared from Petite Home · petitehome.co")
        return lines.joined(separator: "\n")
    }

    /// Cream card, serif title, ingredients, powder blue band at the base.
    @MainActor
    static func card(for recipe: Recipe, householdName: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: cardSize)
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: cardSize)
            Theme.Colors.uiCream.setFill()
            ctx.fill(rect)

            let margin: CGFloat = 96
            var y: CGFloat = margin

            if let photo = recipe.photo, let image = UIImage(data: photo) {
                let photoRect = CGRect(x: margin, y: y, width: cardSize.width - margin * 2, height: 480)
                let path = UIBezierPath(roundedRect: photoRect, cornerRadius: 28)
                ctx.cgContext.saveGState()
                path.addClip()
                image.drawAspectFill(in: photoRect)
                ctx.cgContext.restoreGState()
                y += 480 + 48
            }

            let eyebrow = NSAttributedString(string: "FROM THE \(householdName.uppercased()) KITCHEN", attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold), .kern: 5, .foregroundColor: Theme.Colors.uiPowderBlueDk,
            ])
            eyebrow.draw(at: CGPoint(x: margin, y: y)); y += 48

            let titleStyle = NSMutableParagraphStyle(); titleStyle.lineHeightMultiple = 1.05
            let title = NSAttributedString(string: recipe.title, attributes: [
                .font: Typography.serifUIFont(size: 84), .foregroundColor: Theme.Colors.uiInk, .paragraphStyle: titleStyle,
            ])
            let titleHeight = title.boundingRect(with: CGSize(width: cardSize.width - margin * 2, height: 400), options: [.usesLineFragmentOrigin], context: nil).height
            title.draw(in: CGRect(x: margin, y: y, width: cardSize.width - margin * 2, height: titleHeight + 8)); y += titleHeight + 24

            if !recipe.summary.isEmpty {
                NSAttributedString(string: recipe.summary, attributes: [.font: UIFont.systemFont(ofSize: 30), .foregroundColor: Theme.Colors.uiSandDeep]).draw(at: CGPoint(x: margin, y: y))
                y += 60
            }
            Theme.Colors.uiSand.withAlphaComponent(0.5).setFill()
            ctx.fill(CGRect(x: margin, y: y, width: cardSize.width - margin * 2, height: 2)); y += 40

            let ingredientStyle = NSMutableParagraphStyle(); ingredientStyle.lineSpacing = 10
            let bandTop = cardSize.height - 160
            let bodyFont = UIFont.systemFont(ofSize: 32)
            var shown = 0
            for ingredient in recipe.ingredients {
                let line = NSAttributedString(string: "·  \(ingredient)", attributes: [.font: bodyFont, .foregroundColor: Theme.Colors.uiInk, .paragraphStyle: ingredientStyle])
                let h = line.boundingRect(with: CGSize(width: cardSize.width - margin * 2, height: 200), options: [.usesLineFragmentOrigin], context: nil).height
                if y + h > bandTop - 80 { break }
                line.draw(in: CGRect(x: margin, y: y, width: cardSize.width - margin * 2, height: h + 4)); y += h + 12
                shown += 1
            }
            if shown < recipe.ingredients.count {
                NSAttributedString(string: "and \(recipe.ingredients.count - shown) more in the app", attributes: [.font: UIFont.systemFont(ofSize: 26), .foregroundColor: Theme.Colors.uiSandDeep]).draw(at: CGPoint(x: margin, y: y))
            }

            Theme.Colors.uiPowderBlue.setFill()
            ctx.fill(CGRect(x: 0, y: bandTop, width: cardSize.width, height: 160))
            let mark = NSAttributedString(string: "PETITE HOME CO.", attributes: [
                .font: Typography.serifUIFont(size: 34), .kern: 34 * Theme.Tracking.wordmark, .foregroundColor: Theme.Colors.uiInk,
            ])
            let markSize = mark.size()
            mark.draw(at: CGPoint(x: (cardSize.width - markSize.width) / 2, y: bandTop + (160 - markSize.height) / 2))
        }
    }
}

extension UIImage {
    func drawAspectFill(in rect: CGRect) {
        let scale = max(rect.width / size.width, rect.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(x: rect.midX - drawSize.width / 2, y: rect.midY - drawSize.height / 2)
        draw(in: CGRect(origin: origin, size: drawSize))
    }
}

/// Transferable wrapper so ShareLink can offer the card image and the text together.
struct RecipeCardFile: Transferable {
    let image: UIImage
    let title: String
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.image.pngData() ?? Data() }
            .suggestedFileName { "\($0.title).png" }
    }
}
