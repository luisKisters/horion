import Testing
import Foundation
@testable import HorionKit

@Suite("Sparkle starts only in a normal launch with a feed")
struct UpdatePolicyTests {
    let feed = "https://github.com/luisKisters/horion/releases/latest/download/appcast.xml"

    @Test func normalLaunchOfTheBundleStarts() {
        #expect(UpdatePolicy.startsUpdater(isHeadless: false, isDemo: false, isRunningTests: false, feedURL: feed))
    }

    @Test func headlessModesNeverStart() {
        #expect(!UpdatePolicy.startsUpdater(isHeadless: true, isDemo: false, isRunningTests: false, feedURL: feed))
    }

    @Test func demoNeverStarts() {
        #expect(!UpdatePolicy.startsUpdater(isHeadless: false, isDemo: true, isRunningTests: false, feedURL: feed))
    }

    @Test func unitTestsNeverStart() {
        #expect(!UpdatePolicy.startsUpdater(isHeadless: false, isDemo: false, isRunningTests: true, feedURL: feed))
    }

    @Test func noFeedURLNeverStarts() {
        // `swift run` has no Info.plist, so the bundle has no SUFeedURL
        #expect(!UpdatePolicy.startsUpdater(isHeadless: false, isDemo: false, isRunningTests: false, feedURL: nil))
        #expect(!UpdatePolicy.startsUpdater(isHeadless: false, isDemo: false, isRunningTests: false, feedURL: "  "))
    }
}
