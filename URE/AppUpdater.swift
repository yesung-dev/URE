import Sparkle
import SwiftUI

@MainActor
final class AppUpdater {
    private let controller: SPUStandardUpdaterController?

    init() {
        if Self.isRunningTests {
            controller = nil
            return
        }

        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String
        let hasFeed = !(feed ?? "").isEmpty
        controller = SPUStandardUpdaterController(
            startingUpdater: hasFeed,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    fileprivate var sparkleUpdater: SPUUpdater? {
        controller?.updater
    }

    private static var isRunningTests: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestSessionIdentifier"] != nil
    }
}

struct AppUpdaterCommands: Commands {
    let appUpdater: AppUpdater

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            if let updater = appUpdater.sparkleUpdater {
                CheckForUpdatesView(updater: updater)
            }
        }
    }
}

private struct CheckForUpdatesView: View {
    private let updater: SPUUpdater
    @State private var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        Button("Check for Updates…") {
            updater.checkForUpdates()
        }
        .disabled(!canCheckForUpdates)
        .onAppear {
            canCheckForUpdates = updater.canCheckForUpdates
        }
        .onReceive(updater.publisher(for: \.canCheckForUpdates)) { canCheck in
            canCheckForUpdates = canCheck
        }
    }
}
