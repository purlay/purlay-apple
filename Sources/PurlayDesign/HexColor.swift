import PurlayTokens
import SwiftUI

extension Color {
    /// An sRGB colour from its `0xRRGGBB` value, as the logo and the tokens write it, read as the tokens read it.
    public init(hex: UInt32) {
        let rgba = RGBA(hex: hex)
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}
