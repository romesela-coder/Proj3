import CoreText
import Foundation

enum FontLoader {
    private static let bundledFontNames = [
        "DMMono-Medium",
        "DMMono-Regular",
        "InstrumentSans-Bold",
        "InstrumentSans-Medium",
        "InstrumentSans-Regular",
        "InstrumentSans-SemiBold",
        "SpaceGrotesk-Bold"
    ]

    static func registerBundledFonts() {
        for name in bundledFontNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else {
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
