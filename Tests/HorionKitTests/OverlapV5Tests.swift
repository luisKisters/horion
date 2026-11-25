import Testing
import Foundation
@testable import HorionKit

/// The minute model the timed layout uses (`V5Item`). The v5 algorithm and its "+N" groups are gone (mockup-v14): `OverlapV11Tests`
/// covers the layout.
@Suite("Overlap minute model")
struct OverlapV5Tests {
    @Test func fifteenMinutesOrLessIsShort() {
        #expect(V5Item(id: "x", startMinute: 0, endMinute: 15).isShort && !V5Item(id: "x", startMinute: 0, endMinute: 16).isShort)
        #expect(V5Item(id: "x", startMinute: 60, endMinute: 30).endMinute == 60)      // an end before the start is clamped
    }
}
