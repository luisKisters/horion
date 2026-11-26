import HorionKit
import Sparkle
import SwiftUI

/// The app's updater: Sparkle 2 with its standard user interface. It starts only when `UpdatePolicy` allows it, which is a
/// normal launch of the real bundle. Nil in the headless modes, under `--demo`, in the unit tests and under `swift run`.
@MainActor
enum AppUpdater {
    static let controller: SPUStandardUpdaterController? = {
        let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        guard UpdatePolicy.startsUpdater(isHeadless: launchOptions.isHeadless, isDemo: launchOptions.demo,
                                         isRunningTests: isRunningTests, feedURL: feedURL) else { return nil }
        return SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }()
}

/// "Check for Updates…", placed under About. It is disabled while Sparkle cannot check (Sparkle's SwiftUI pattern).
struct CheckForUpdatesView: View {
    @ObservedObject private var model: CheckForUpdatesModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        model = CheckForUpdatesModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates\u{2026}", action: updater.checkForUpdates)
            .disabled(!model.canCheckForUpdates)
    }
}

/// Publishes whether Sparkle can check for updates now (KVO on `SPUUpdater.canCheckForUpdates`).
final class CheckForUpdatesModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }
}
