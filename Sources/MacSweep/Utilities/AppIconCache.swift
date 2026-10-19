import Foundation
import AppKit
import UniformTypeIdentifiers

public final class AppIconCache: @unchecked Sendable {
    public static let shared = AppIconCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 500
    }

    /// Returns the system icon for a specific file or folder URL.
    public func icon(forURL url: URL) -> NSImage {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        if FileManager.default.fileExists(atPath: url.path) {
            let img = NSWorkspace.shared.icon(forFile: url.path)
            cache.setObject(img, forKey: key)
            return img
        }

        // Fallback for file extension if file doesn't exist
        let ext = url.pathExtension
        if !ext.isEmpty, let utType = UTType(filenameExtension: ext) {
            let img = NSWorkspace.shared.icon(for: utType)
            cache.setObject(img, forKey: key)
            return img
        }

        let generic = NSWorkspace.shared.icon(for: .application)
        return generic
    }

    /// Looks up the system icon for an installed app by its bundle identifier or display name.
    public func icon(forAppName name: String?, bundleIdentifier: String? = nil) -> NSImage? {
        let key = (bundleIdentifier ?? name ?? "") as NSString
        guard !key.isEqual(to: "") else { return nil }

        if let cached = cache.object(forKey: key) {
            return cached
        }

        // 1. Try NSWorkspace urlForApplication with bundleId
        if let bId = bundleIdentifier, !bId.isEmpty,
           let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bId) {
            let img = NSWorkspace.shared.icon(forFile: appUrl.path)
            cache.setObject(img, forKey: key)
            return img
        }

        // 2. Try common app directories by name
        if let appName = name, !appName.isEmpty {
            let searchPaths = [
                "/Applications/\(appName).app",
                "/System/Applications/\(appName).app",
                "/System/Cryptexes/App/System/Applications/\(appName).app",
                NSHomeDirectory() + "/Applications/\(appName).app"
            ]

            for path in searchPaths {
                if FileManager.default.fileExists(atPath: path) {
                    let img = NSWorkspace.shared.icon(forFile: path)
                    cache.setObject(img, forKey: key)
                    return img
                }
            }
        }

        return nil
    }
}
