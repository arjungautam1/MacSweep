import Foundation
import AppKit

/// Service responsible for checking and guiding macOS Full Disk Access permissions.
@MainActor
public final class DiskPermissionService: ObservableObject {
    public static let shared = DiskPermissionService()

    @Published public private(set) var hasFullDiskAccess: Bool = false

    private init() {
        checkAccess()
    }

    /// Re-evaluates whether Full Disk Access is granted by attempting to read a TCC-restricted user directory.
    @discardableResult
    public func checkAccess() -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let safariDir = home.appendingPathComponent("Library/Safari")

        // In macOS, ~/Library/Safari is strictly gated by TCC (Full Disk Access).
        // If an app lacks Full Disk Access, contentsOfDirectory throws or returns empty.
        var granted = false
        if FileManager.default.fileExists(atPath: safariDir.path) {
            granted = (try? FileManager.default.contentsOfDirectory(at: safariDir, includingPropertiesForKeys: nil)) != nil
        } else {
            // Fallback: test read on ~/Library/Containers
            let containersDir = home.appendingPathComponent("Library/Containers")
            granted = (try? FileManager.default.contentsOfDirectory(at: containersDir, includingPropertiesForKeys: nil)) != nil
        }

        self.hasFullDiskAccess = granted
        return granted
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Full Disk Access.
    public func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
