import Testing
import UIKit

@testable import Purlay

@MainActor
@Suite("the app's accent")
struct AccentColorTests {
    // The AccentColor asset was set to the token accent (#2563EB), but no build setting names it as the app's accent
    // (ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME), so the system ignores it: Try Again, the notice's close button and every
    // other tinted control are the system blue, beside a Sign In that is the brand blue.
    @Test("is the token accent, so a system control is the same blue as Sign In")
    func tintIsTheTokenAccent() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let control = UIView()
        window.addSubview(control)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        try #require(control.tintColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        // PurlayTokens' `accent`, #2563EB, the same in every appearance.
        let accent = (red: 0x25 / 255.0, green: 0x63 / 255.0, blue: 0xEB / 255.0)
        #expect(
            abs(red - accent.red) < 0.01 && abs(green - accent.green) < 0.01 && abs(blue - accent.blue) < 0.01,
            "the tint is (\(red), \(green), \(blue)), not the token accent")
    }
}
