import Testing
@testable import Horion

/// The colour system of mockup-v16 round 3: states are fitted to contrast on their surface, and text stays readable on them.
@Suite("Colour system")
struct ContrastSystemTests {
    @Test(arguments: [true, false]) func statesAreFittedOnTheirSurface(dark: Bool) {
        let t = InkRGB.of(dark), b = dark ? InkRGB.darkBase : InkRGB.lightBase
        let sel = Contrast.ratio(b.rail, t.selected), hover = min(Contrast.hover, sel.squareRoot())
        #expect(sel <= Contrast.selected + 0.03 && sel > 1.1)
        // Every surface gets the same hover step.
        for (surface, state) in [(b.bg, t.hover), (b.rail, t.hoverRail), (b.bg2, t.raisedHover), (b.pop, t.popHover), (t.selected, t.selectedHover)] {
            #expect(abs(Contrast.ratio(surface, state) - hover) < 0.03, "hover \(state.c8.hex) on \(surface.c8.hex)")
        }
        #expect(Contrast.ratio(b.bg1, t.segRing) >= Contrast.edge)
        // States are neutral greys.
        for c in [t.hover, t.hoverRail, t.selected, t.selectedHover, t.segRing, t.todayTint] { #expect(c.r == c.g && c.g == c.b) }
    }

    @Test(arguments: [true, false]) func textPassesItsFloorsOnEveryStateFill(dark: Bool) {
        let t = InkRGB.of(dark), f = Contrast.textFloors(dark: dark)
        for fill in [t.hover, t.hoverRail, t.selected, t.selectedHover, t.raisedHover, t.popHover] {
            for (i, text) in [t.fg, t.fg2, t.fg3].enumerated() { #expect(ColorMath.ok(text.c8, fill.c8, f[i]), "text \(i + 1) on \(fill.c8.hex)") }
        }
    }

    /// Dark: the mini month's week band is clearly visible on the sidebar (it was 1.08:1).
    @Test func darkBandIsVisible() { #expect(Contrast.ratio(InkRGB.dark.rail, InkRGB.dark.selected) >= 1.35) }

    /// design/mockup-v21: hover inside a selected band steps back toward the shade, so its text gains contrast.
    @Test(arguments: [true, false]) func hoverInsideSelectedStepsBack(dark: Bool) {
        let t = InkRGB.of(dark)
        #expect((Contrast.luminance(t.selectedHover) < Contrast.luminance(t.selected)) == dark)
        #expect(Contrast.ratio(t.fg, t.selectedHover) > Contrast.ratio(t.fg, t.selected))
    }

    /// design/mockup-v21: every shade × fg1/fg2/fg3 × (shade, hover, selected, hover in selected), and every button label, pass.
    @Test(arguments: [true, false]) func everyShadePairPasses(dark: Bool) {
        let b = dark ? InkRGB.darkBase : InkRGB.lightBase, t = InkRGB.of(dark), f = Contrast.textFloors(dark: dark)
        for s in Shade.allCases {
            let k = b.shadeInk(s, dark: dark)
            for fill in [k.base, k.hover, k.selected, k.selectedHover, k.secondary, k.secondaryHover] {
                for (i, text) in [b.fg, b.fg2, b.fg3].enumerated() { #expect(ColorMath.ok(text.c8, fill.c8, f[i]), "\(s) fg\(i + 1) on \(fill.c8.hex)") }
            }
            // Visible: hover and selected step off the shade; the Secondary button has a 1.5:1 edge.
            #expect(Contrast.ratio(k.base, k.hover) > 1.04 && Contrast.ratio(k.base, k.selected) > 1.08, "\(s) states")
            #expect(Contrast.ratio(k.base, k.secondaryEdge) >= Contrast.softEdge, "\(s) secondary edge")
            #expect(abs(Contrast.ratio(k.selected, k.selectedHover) - Contrast.ratio(k.base, k.hover)) < 0.03, "\(s) hover in selected")
        }
        #expect(ColorMath.ok(b.bg.c8, t.fg.c8, f[0]) && ColorMath.ok(b.bg.c8, t.actHover.c8, f[0]), "Primary label")
        #expect(ColorMath.ok(InkRGB.white.c8, t.dangerFill.c8, Contrast.labelFloor) && ColorMath.ok(InkRGB.white.c8, t.dangerHover.c8, Contrast.labelFloor), "Danger label")
    }
}
