import SwiftUI
import CoreText

/// Type. Headlines and section titles use the site's serif, Fraunces, bundled
/// from Google Fonts (variable TTF, see Resources/Fonts). Body, labels and
/// inputs use SF Pro via the system font. Nothing else is shipped.
enum Typography {

    static let serifFamily = "Fraunces"

    // Fraunces variation axes.
    private static let wghtTag: UInt32 = 0x77676874 // 'wght'
    private static let opszTag: UInt32 = 0x6F70737A // 'opsz'
    private static let softTag: UInt32 = 0x534F4654 // 'SOFT'
    private static let wonkTag: UInt32 = 0x574F4E4B // 'WONK'

    /// Whether the bundled serif registered. If not, falls back to the system serif design.
    private static var serifAvailable: Bool = {
        UIFont.familyNames.contains(serifFamily)
    }()

    /// A UIFont for the serif at a point size, with optical size tracking the
    /// point size the way the browser does it (`font-optical-sizing: auto`).
    static func serifUIFont(size: CGFloat, weight: CGFloat = 400) -> UIFont {
        guard serifAvailable else {
            let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withDesign(.serif)
                ?? UIFont.systemFont(ofSize: size).fontDescriptor
            return UIFont(descriptor: descriptor, size: size)
        }
        let variations: [NSNumber: NSNumber] = [
            NSNumber(value: wghtTag): NSNumber(value: Double(weight)),
            NSNumber(value: opszTag): NSNumber(value: Double(min(max(size, 9), 144))),
            NSNumber(value: softTag): 0,
            NSNumber(value: wonkTag): 0,
        ]
        let attributes: [UIFontDescriptor.AttributeName: Any] = [
            .family: serifFamily,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variations,
        ]
        let descriptor = UIFontDescriptor(fontAttributes: attributes)
        return UIFont(descriptor: descriptor, size: size)
    }

    static func serif(_ size: CGFloat, weight: CGFloat = 400) -> Font {
        Font(serifUIFont(size: size, weight: weight))
    }

    // MARK: Roles

    /// Onboarding hook lines. 28–32pt, ink, left-aligned, generous line height.
    static let hook = serif(30)
    /// Screen titles.
    static let title = serif(28)
    /// Section titles within a screen.
    static let sectionTitle = serif(22)
    /// The completeness number in the ring.
    static func ringNumber(_ size: CGFloat) -> Font { serif(size) }
    /// The wordmark, serif capitals.
    static let wordmark = serif(20)

    static let body = Font.system(.body)
    static let bodyEmphasis = Font.system(.body, weight: .semibold)
    static let callout = Font.system(.callout)
    static let caption = Font.system(.footnote)
    static let label = Font.system(.subheadline, weight: .medium)
    static let button = Font.system(.body, weight: .semibold)
    static let capsLabel = Font.system(.caption, weight: .semibold)
}

extension Text {
    /// The site's small caps label: uppercase, tracked, muted.
    func capsLabel() -> some View {
        self.font(Typography.capsLabel)
            .textCase(.uppercase)
            .kerning(Theme.Tracking.caps * 11)
            .foregroundStyle(Theme.Colors.sandDeep)
    }
}
