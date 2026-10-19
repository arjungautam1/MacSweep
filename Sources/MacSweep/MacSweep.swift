import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load AppIcon from bundle resources or current directory for dock icon
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: iconURL) {
            NSApplication.shared.applicationIconImage = image
        } else {
            let localURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("AppIcon.icns")
            if let image = NSImage(contentsOf: localURL) {
                NSApplication.shared.applicationIconImage = image
            }
        }

        // Initialize notification permissions & background storage monitoring
        StorageNotificationService.shared.requestAuthorization()
        StorageNotificationService.shared.startBackgroundMonitoring(intervalSeconds: 600)
        StorageNotificationService.shared.checkForLargeFiles()
    }
}

struct MenuBarLabelView: View {
    @ObservedObject var runnerService = MenuBarRunnerService.shared
    @ObservedObject var telemetry = SystemTelemetryService.shared
    @ObservedObject var appState = AppState.shared

    var body: some View {
        HStack(spacing: 4) {
            if runnerService.displayMode != .metricsOnly {
                if let nsImage = runnerService.currentFrameImage {
                    Image(nsImage: nsImage)
                } else {
                    Image(systemName: "paintbrush.pointed.fill")
                }
            }
            if runnerService.displayMode != .runnerOnly {
                Text(String(format: "%.0f%% · %@", telemetry.cpuUsagePercentage, appState.storageOverview.freeBytes.formattedBytes))
            }
        }
    }
}

@main
struct MacSweeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup("MacSweep", id: "mainWindow") {
            MainView(appState: appState)
                .frame(minWidth: 1040, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            MenuBarLabelView()
        }
        .menuBarExtraStyle(.window)
    }
}
