import Foundation

/// Whether this process starts the update checker (Sparkle). Only a normal launch of the real app bundle does:
/// never a headless mode (`--snapshot`, `--walkthrough`, `--perf`), never `--demo`, never the unit tests, and never a run
/// without a feed URL, such as `swift run` (no Info.plist, so no `SUFeedURL`).
public enum UpdatePolicy {
    public static func startsUpdater(isHeadless: Bool, isDemo: Bool, isRunningTests: Bool, feedURL: String?) -> Bool {
        guard !isHeadless, !isDemo, !isRunningTests else { return false }
        guard let feedURL, !feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return true
    }
}
