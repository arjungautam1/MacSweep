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

@main
struct MacSweeperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup("MacSweeper", id: "mainWindow") {
            MainView(appState: appState)
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "wand.and.stars")
                Text(appState.storageOverview.freeBytes.formattedBytes + " Free")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
