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
/// Light is the brand's native appearance. Dark mode keeps the same warm family:
/// every token is a light/dark pair, so views never branch on the color scheme.
/// `Fixed` holds the few colors that stay the same in both (the dark "moment"
/// screens and the ink feature card on the paywall).
enum Theme {

    // MARK: Colour

    enum Colors {
        /// App background, every screen. web `--bg`, also the site's theme-color.
        static let cream = Color(light: 0xFCF8F2, dark: 0x171311)
        /// Cards, grouped lists, sheet backgrounds. web `--bg-alt` ("kraft", the Family File section).
        static let creamDeep = Color(light: 0xF4EDE2, dark: 0x241E1A)
        /// A third, warmer ground between sections. web `--tint`.
        static let creamTint = Color(light: 0xF8EFE4, dark: 0x1E1916)
        /// Primary brand accent: the pale powder blue. brand `--ph-blue`. Fills, pills, selected chips (ink on top).
        static let powderBlue = Color(light: 0xC9DCE8, dark: 0x416C87)
        /// The deeper powder blue for fills: primary buttons, selected state, the progress ring. Ink text on top. brand `--ph-blue-deep`.
        static let powderBlueDk = Color(light: 0x9DBBD0, dark: 0x4C7C97)
        /// Powder blue as text and tint on cream: links, accents, toggles. A darker cut of the same hue so it reads (5.4:1).
        static let accentText = Color(light: 0x4A6A7E, dark: 0x8FB8CF)
        /// Powder blue as a whole-section ground. brand "Powder blue mist".
        static let powderBlueMist = Color(light: 0xE4EEF4, dark: 0x1F2D36)
        /// Light brown: icons, kid avatars, secondary accent. brief (the site has no icon-weight sand token).
        static let sand = Color(light: 0xC9B69A, dark: 0x7A6B5C)
        /// Secondary text, captions, disabled labels. The site's token is #A8927A, which is 2.8:1 on cream;
        /// this is the same brown cut dark enough to read (4.9:1). Use `sandMid` for the exact site value.
        static let sandDeep = Color(light: 0x7E6A55, dark: 0xB3A698)
        /// The site's `sandDeep` exactly, for dividers, placeholders and anything that is not text.
        static let sandMid = Color(light: 0xA8927A, dark: 0x7A6B5C)
        /// 1pt rules and dividers. web `--rule`.
        static let rule = Color(light: 0xE6DBCC, dark: 0x352D28)
        /// Primary text. web `--ink` (warm charcoal, never pure black; warm off-white in the dark).
        static let ink = Color(light: 0x2F2A26, dark: 0xF3ECE2)
        /// Input fields, on-button text. web `--surface`. A slightly raised surface in the dark.
        static let white = Color(light: 0xFFFFFF, dark: 0x2A2420)
        /// Task complete, 100% file. brief.
        static let success = Color(light: 0x8FB59A, dark: 0x8FB59A)
        /// Expiration approaching. brief (sand family, not red).
        static let warn = Color(light: 0xD9A66A, dark: 0xD9A66A)
        /// Overdue, destructive actions only. brief, darkened to 4.6:1 on cream for 13pt text.
        static let danger = Color(light: 0xA8584A, dark: 0xD98A7D)

        /// Colors that do not flip with the appearance: the dark moment screens,
        /// the paywall's ink card, and the text that sits on them.
        enum Fixed {
            static let ink = Color(hex: 0x2F2A26)
            static let cream = Color(hex: 0xFCF8F2)
            static let powderBlue = Color(hex: 0xC9DCE8)
        }
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
    /// A color that follows the appearance: one hex for light, one for dark.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }

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
    static let uiCreamDeep = UIColor(hex: 0xF4EDE2)
    static let uiPowderBlue = UIColor(hex: 0xC9DCE8)
    static let uiPowderBlueDk = UIColor(hex: 0x9DBBD0)
    static let uiAccentText = UIColor(hex: 0x4A6A7E)
    static let uiSand = UIColor(hex: 0xC9B69A)
    static let uiSandDeep = UIColor(hex: 0x7E6A55)
    static let uiRule = UIColor(hex: 0xE6DBCC)
    static let uiInk = UIColor(hex: 0x2F2A26)
}
