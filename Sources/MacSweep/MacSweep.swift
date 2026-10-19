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
    }
}

@main
struct MacSweepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 980, minHeight: 640)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
