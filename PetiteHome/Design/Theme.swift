import SwiftUI

/// Petite Home Co. design tokens.
///
/// The website is the source of truth. Every value below is annotated with
/// where it came from in the `petite-powder` repo:
///   - `web`   = 02-web/src/app/globals.css (the live September 2026 site)
///   - `brand` = 00-brand/color/tokens.css and 00-brand/brand-guidelines.md
///   - `brief` = the iOS brief's target palette, used only where the site has
///               no token for that role.
///
/// The brand is light. Dark mode is out of scope for v1; the app forces the
/// light appearance in `PetiteHomeApp`.
enum Theme {

    // MARK: Colour

    enum Colors {
        /// App background, every screen. web `--bg`, also the site's theme-color.
        static let cream = Color(hex: 0xFCF8F2)
        /// Cards, grouped lists, sheet backgrounds. web `--bg-alt` ("kraft", the Family File section).
        static let creamDeep = Color(hex: 0xF2E7D8)
        /// A third, warmer ground between sections. web `--tint`.
        static let creamTint = Color(hex: 0xF8EFE4)
        /// Primary brand accent: the pale powder blue. brand `--ph-blue`. Fills, pills, selected chips (ink on top).
        static let powderBlue = Color(hex: 0xA9CBDD)
        /// Powder blue as a fill you can put white text on: primary buttons, progress ring. brand `--ph-blue-deep`.
        static let powderBlueDk = Color(hex: 0x3F6379)
        /// Powder blue as a whole-section ground. brand "Powder blue mist".
        static let powderBlueMist = Color(hex: 0xE7EFF4)
        /// Light brown: icons, kid avatars, secondary accent. brief (the site has no icon-weight sand token).
        static let sand = Color(hex: 0xC9B69A)
        /// Secondary text, captions, disabled labels. web `--muted` (5.6:1 on cream).
        static let sandDeep = Color(hex: 0x6E6259)
        /// 1pt rules and dividers. web `--rule`.
        static let rule = Color(hex: 0xE6DBCC)
        /// Primary text. web `--ink` (warm charcoal, never pure black).
        static let ink = Color(hex: 0x2B2420)
        /// Input fields, on-button text. web `--surface`.
        static let white = Color(hex: 0xFFFFFF)
        /// Task complete, 100% file. brief.
        static let success = Color(hex: 0x8FB59A)
        /// Expiration approaching. brief (sand family, not red).
        static let warn = Color(hex: 0xD9A66A)
        /// Overdue, destructive actions only. brief.
        static let danger = Color(hex: 0xC97A6D)
    }

    // MARK: Shape

    enum Radius {
        /// Cards. web `--radius`.
        static let card: CGFloat = 14
        /// Inputs and buttons. web `--radius-sm`.
        static let control: CGFloat = 10
        /// Chips and avatars are full-round.
        static let pill: CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        /// Horizontal screen gutter.
        static let gutter: CGFloat = 20
    }

    enum Metrics {
        static let primaryButtonHeight: CGFloat = 52
        static let dividerOpacity: Double = 0.3
        static let dividerHeight: CGFloat = 1
        static let avatarSize: CGFloat = 44
        static let ringLineWidth: CGFloat = 10
    }

    // MARK: Tracking

    enum Tracking {
        /// The wordmark only. brand `--ph-tracking-display`.
        static let wordmark: CGFloat = 0.3
        /// Small caps labels. brand `--ph-tracking-caps`.
        static let caps: CGFloat = 0.16
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

/// UIKit mirrors of the tokens for UIGraphics work (the PDF exporter).
extension Theme.Colors {
    static let uiCream = UIColor(hex: 0xFCF8F2)
    static let uiCreamDeep = UIColor(hex: 0xF2E7D8)
    static let uiPowderBlue = UIColor(hex: 0xA9CBDD)
    static let uiPowderBlueDk = UIColor(hex: 0x3F6379)
    static let uiSand = UIColor(hex: 0xC9B69A)
    static let uiSandDeep = UIColor(hex: 0x6E6259)
    static let uiRule = UIColor(hex: 0xE6DBCC)
    static let uiInk = UIColor(hex: 0x2B2420)
}
