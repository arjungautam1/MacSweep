import Foundation
import UserNotifications
import AppKit

public final class StorageNotificationService: @unchecked Sendable {
    public static let shared = StorageNotificationService()

    private var notifiedPaths = Set<String>()
    private var timer: Timer?
    private var lastLowSpaceNotifiedDate: Date?

    public init() {}

    /// Requests authorization from macOS Notification Center.
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            } else if granted {
                print("MacSweeper notification authorization granted.")
            }
        }
    }

    /// Scans for large files (> 500 MB) and sends a notification for the largest new file found.
    public func checkForLargeFiles(minimumSizeBytes: Int64 = 500_000_000) {
        Task {
            let files = LargeFileAnalyzerService.shared.scanLargeFiles(minimumSizeBytes: minimumSizeBytes)
            
            // Check for any unnotified large files
            let newLargeFiles = files.filter { !self.notifiedPaths.contains($0.path.path) }
            if let largest = newLargeFiles.sorted(by: { $0.size > $1.size }).first {
                self.notifiedPaths.insert(largest.path.path)
                self.sendLargeFileNotification(for: largest)
            }

            // Also check for low disk space (< 15 GB)
            let storage = StorageOverview.current()
            let fifteenGB: Int64 = 15 * 1024 * 1024 * 1024
            if storage.freeBytes < fifteenGB {
                let shouldNotify: Bool
                if let last = self.lastLowSpaceNotifiedDate {
                    shouldNotify = Date().timeIntervalSince(last) > 3600 * 6 // at most once every 6 hours
                } else {
                    shouldNotify = true
                }

                if shouldNotify {
                    self.lastLowSpaceNotifiedDate = Date()
                    self.sendLowSpaceNotification(freeBytes: storage.freeBytes)
                }
            }
        }
    }

    /// Sends a native macOS notification for a large file.
    public func sendLargeFileNotification(for file: LargeFileItem) {
        let content = UNMutableNotificationContent()
        content.title = "Large File Detected"
        content.subtitle = "\(file.name) (\(file.size.formattedBytes))"
        let folderName = file.path.deletingLastPathComponent().lastPathComponent
        content.body = "This file occupies significant storage in \(folderName). Open MacSweeper to review or free up space."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "large-file-\(file.path.path.hashValue)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }

    /// Sends a native macOS warning when free storage is critically low.
    public func sendLowSpaceNotification(freeBytes: Int64) {
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Low Disk Space Alert"
        content.subtitle = "Only \(freeBytes.formattedBytes) remaining"
        content.body = "Your Mac is running low on disk space. Open MacSweeper to safely remove application caches and orphaned leftovers."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "low-disk-space",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Starts a recurring timer to check disk space and big files in the background.
    public func startBackgroundMonitoring(intervalSeconds: TimeInterval = 600) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { [weak self] _ in
                self?.checkForLargeFiles()
            }
        }
    }
}
