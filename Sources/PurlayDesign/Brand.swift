import PurlayTokens
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// A token as a colour that follows the system appearance: its `light` value in light mode and its `dark` value in dark.
    init(_ token: TokenColor) {
        #if canImport(UIKit)
        self.init(
            uiColor: UIColor { traits in
                UIColor(token.value(in: traits.userInterfaceStyle == .dark ? .dark : .light))
            })
        #else
        self.init(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                return NSColor(token.value(in: isDark ? .dark : .light))
            })
        #endif
    }
}

#if canImport(UIKit)
extension UIColor {
    fileprivate convenience init(_ rgba: RGBA) {
        self.init(red: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
    }
}
#else
extension NSColor {
    fileprivate convenience init(_ rgba: RGBA) {
        self.init(srgbRed: rgba.red, green: rgba.green, blue: rgba.blue, alpha: rgba.alpha)
    }
}
#endif

/// The colours the app's own marks are drawn in, from the shared tokens, so a change on the server reaches the app with the
/// next `purlay-swift` and nowhere else.
public enum Brand {
    /// The one accent fill: a primary button, the tint. Never text; text on it is `onAccent`.
    public static let accent = Color(Colors.accent)
    public static let onAccent = Color(Colors.onAccent)
    public static let ink = Color(Colors.ink)
    public static let inkMuted = Color(Colors.inkMuted)
}
