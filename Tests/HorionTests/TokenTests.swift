import Testing
import Foundation
import AppKit
import SwiftUI
@testable import Horion

/// The design tokens (v5: the locked v11 design): one colour table that matches the mockup, used by SwiftUI and CoreGraphics alike, and one segmented control.
@MainActor
@Suite("design tokens")
struct TokenTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The sRGB components of a SwiftUI colour in an appearance.
    static func rgb(_ c: Color, dark: Bool) -> RGB {
        var out = RGB(0, 0, 0)
        NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
            let n = NSColor(c).usingColorSpace(.sRGB)!
            out = RGB(Double(n.redComponent), Double(n.greenComponent), Double(n.blueComponent))
        }
        return out
    }

    static func close(_ a: RGB, _ b: RGB) -> Bool { abs(a.r - b.r) < 0.002 && abs(a.g - b.g) < 0.002 && abs(a.b - b.b) < 0.002 }

    @Test func canvasInkAndPalettesShareTheThemeColours() {
        for dark in [true, false] {
            let ink = EventPainter.Ink.of(dark)
            let theme = Self.rgb(Theme.bg, dark: dark)
            let cg = ink.bg.components!
            #expect(Self.close(RGB(Double(cg[0]), Double(cg[1]), Double(cg[2])), theme))
            #expect(Self.close(Self.rgb(Theme.fg, dark: dark), InkRGB.of(dark).fg))
            #expect(Self.close(Self.rgb(Theme.pop, dark: dark), InkRGB.of(dark).pop))
            #expect(Palettes.bg(dark) == InkRGB.of(dark).bg && Palettes.fg(dark) == InkRGB.of(dark).fg)
        }
        #expect(Self.close(Self.rgb(Theme.bg, dark: true), RGB(hex: "#0B0B0C")))
        #expect(Self.close(Self.rgb(Theme.rail, dark: false), RGB(hex: "#F4F4F5")))
        // Paper is neutral now (no warm cast).
        #expect(InkRGB.light.bg == RGB(hex: "#FBFBFB"))
    }

    @Test func microLabelIsSentenceCase() {
        #expect(MicroLabel.sentence("SIDE PROJECT") == "Side project")
        #expect(MicroLabel.sentence("work") == "Work")
    }
}
